const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

// =======================================================
// 1. دالة مساعد المبيعات الذكي (ناصح)
// =======================================================
exports.askNaaseh = onCall(
  { secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    const userPrompt = request.data?.prompt;
    if (!userPrompt) {
      throw new HttpsError("invalid-argument", "برجاء إدخال السؤال");
    }

    const apiKey = process.env.GEMINI_API_KEY ? process.env.GEMINI_API_KEY.trim() : '';

    try {
      const db = admin.firestore();

      const productSnap = await db.collection('products').limit(15).get();
      const catalogContext = productSnap.docs
        .map(d => `${d.data().name} بسعر ${d.data().price} ج.م`)
        .join(' | ');

      const systemInstruction = `
      أنت "ناصح"، مساعد مبيعات ذكي وودود لمتجر Ramy Store.
      الكاتالوج الحالي للمتجر بالأسعار: ${catalogContext}.
      مهامك الأساسية:
      1. إذا سأل العميل عن منتج معين، أعطه تفاصيله وسعره بدقة.
      2. إذا ذكر العميل ميزانية مالية محددة، اقترح عليه المنتج المناسب لهذه الميزانية تماماً، أو مجموعة منتجات (كومبو) لا تتجاوز هذا المبلغ.
      3. كن دقيقاً، مختصرًا، وتحدث باللغة العربية الفصحى فقط.
      `;

      // 👈 تم إعادة الموديل الصحيح والأحدث الذي كنت تستخدمه بنجاح
      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${apiKey}`;

      const res = await axios.post(
        url,
        {
          systemInstruction: { parts: [{ text: systemInstruction }] },
          contents: [{ parts: [{ text: userPrompt }] }]
        },
        {
          headers: { 'Content-Type': 'application/json' }
        }
      );

      const replyText = res.data.candidates?.[0]?.content?.parts?.[0]?.text || "عفواً، لم أستطع صياغة رد حالياً.";
      return { reply: replyText };

    } catch (e) {
      const errorMsg = e.response?.data?.error?.message || e.message;
      console.error("Gemini Real Error:", errorMsg);
      throw new HttpsError("internal", errorMsg);
    }
  }
);

// =======================================================
// 2. دالة إرسال إشعار تلقائي للعميل عند تغير حالة الطلب
// =======================================================
exports.sendOrderUpdateNotification = onDocumentUpdated("orders/{orderId}", async (event) => {
    const newValue = event.data.after.data();
    const previousValue = event.data.before.data();

    if (newValue.status === previousValue.status) {
      return null;
    }

    const userId = newValue.userId;
    const newStatus = newValue.status;
    const orderId = event.params.orderId;

    if (!userId) {
      console.log("الطلب لا يحتوي على userId");
      return null;
    }

    try {
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log(`لا يوجد fcmToken للعميل: ${userId}`);
        return null;
      }

      let bodyMsg = `تم تحديث حالة طلبك إلى: ${newStatus}`;
      if (newStatus.toLowerCase() === 'processing') bodyMsg = 'طلبك قيد التجهيز الآن 📦';
      if (newStatus.toLowerCase() === 'shipped') bodyMsg = 'مندوبنا في الطريق إليك 🚚';
      if (newStatus.toLowerCase() === 'delivered') bodyMsg = 'شكراً لتسوقك من رامي ستور! نأمل أن يعجبك المنتج ✅';
      if (newStatus.toLowerCase() === 'cancelled') bodyMsg = 'تم إلغاء طلبك، وإرجاع المبالغ لحسابك ❌';

      const payload = {
        token: fcmToken,
        notification: {
          title: "تحديث حالة الطلب 🛒",
          body: bodyMsg,
        },
        data: {
          type: "order_update",
          orderId: orderId,
        },
      };

      const response = await admin.messaging().send(payload);
      console.log("✅ تم إرسال الإشعار بنجاح:", response);
      return response;

    } catch (error) {
      console.error("❌ فشل إرسال الإشعار:", error);
      return null;
    }
});

// =======================================================
// 3. دالة الدفع الآمن عبر Paymob
// =======================================================
exports.createSecurePaymobOrder = onCall(
  { secrets: ["PAYMOB_API_KEY"] },
  async (request) => {
    const data = request.data;

    const totalAmount = data.totalAmount || 0;
    const amountCents = Math.round(totalAmount * 100).toString();

    const apiKey = process.env.PAYMOB_API_KEY ? process.env.PAYMOB_API_KEY.trim() : '';
    const integrationId = data.isLive ? "LIVE_INTEGRATION_ID" : "5911923";

    if (!apiKey) {
      throw new HttpsError("failed-precondition", "مفتاح الدفع غير متوفر على السيرفر");
    }

    try {
      const authRes = await axios.post("https://accept.paymob.com/api/auth/tokens", { api_key: apiKey });
      const token = authRes.data.token;

      const orderRes = await axios.post("https://accept.paymob.com/api/ecommerce/orders", {
              auth_token: token,
              delivery_needed: "false",
              amount_cents: amountCents,
              currency: "EGP",
              items: []
            });

      const paymentKeyRes = await axios.post("https://accept.paymob.com/api/acceptance/payment_keys", {
        auth_token: token,
        amount_cents: amountCents,
        expiration: 3600,
        order_id: orderRes.data.id,
        billing_data: data.billingData,
        currency: "EGP",
        integration_id: integrationId
      });

      return { paymentToken: paymentKeyRes.data.token };
    } catch (error) {
      console.error("Paymob Error:", error.response?.data || error.message);
      throw new HttpsError("internal", "فشل إعداد الدفع عبر بوابة بيموب");
    }
  }
);

// =======================================================
// 4. دالة تحليل الفواتير بالذكاء الاصطناعي (AI Invoice Parser)
// =======================================================
exports.analyzeInvoice = onCall(
  { secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    const base64Image = request.data?.imageBase64;
    if (!base64Image) {
      throw new HttpsError("invalid-argument", "برجاء إرسال صورة الفاتورة");
    }

    const apiKey = process.env.GEMINI_API_KEY ? process.env.GEMINI_API_KEY.trim() : '';
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "مفتاح الذكاء الاصطناعي غير متوفر على السيرفر");
    }

    try {
      const systemInstruction = `
            You are an expert ERP invoice parser. Analyze this invoice image accurately (Arabic or English, handwritten or typed).
            Extract the supplier name, invoice number, totals, and list of items.
            CRITICAL RULE 1: Translate and standardize all item names strictly into ENGLISH.
            CRITICAL RULE 2: Assign each item a 'mainCategory' and 'subCategory' based ONLY on this exact taxonomy:

            Main Categories -> [Sub Categories]:
            Computers & Systems -> [Desktops, Laptops, Servers & Workstations]
            PC Components -> [Processors / CPUs, Motherboards, Memory / RAM, Storage / HDD / SSD / NVMe, Graphics Cards / GPUs, Power Supplies / PSU, Computer Cases, Cooling Systems]
            Displays & Monitors -> [Standard Monitors, Gaming Monitors]
            Peripherals & Accessories -> [Keyboards, Mice & Pointers, Headsets & Audio, Webcams, Mousepads & Stands]
            Cables & Adapters -> [Video Cables, Data Cables, Power Cables, Adapters & Hubs]
            Laptop Specific Parts -> [Laptop Chargers, Laptop Batteries, Laptop Screens]
            Mobile Accessories -> [Mobile Chargers, Screen Protectors, Mobile Cases, Power Banks]
            Networking -> [Routers & Switches, Network Cables]
            Micro-Components & Maintenance -> [Sockets & Connectors, ICs & Chips, Jumpers & Screws, Thermal Paste & Cleaning]

            If you are absolutely unsure, use "Uncategorized" for both.

            Return ONLY a JSON object:
            {
              "partnerName": "Supplier Name in English",
              "invoiceNumber": "Invoice Number",
              "subtotal": 1000.0,
              "discountAmount": 0.0,
              "totalAmount": 1000.0,
              "date": "2026-09-23",
              "items": [
                {
                  "productName": "Standardized English Name",
                  "quantity": 1,
                  "unitPrice": 100.0,
                  "mainCategory": "Computers & Systems", // Must be from the main categories list
                  "subCategory": "Laptops" // Must be from the corresponding sub categories list
                }
              ]
            }
            `;
      // 👈 تم الترقية للموديل الشغال 3.6 لإنهاء مشكلة الـ Null
      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${apiKey}`;

      const res = await axios.post(
        url,
        {
          systemInstruction: {
            parts: [{ text: systemInstruction }]
          },
          contents: [
            {
              parts: [
                { text: "Extract invoice details from this image accurately and return only JSON." },
                {
                  inlineData: {
                    mimeType: "image/jpeg",
                    data: base64Image
                  }
                }
              ]
            }
          ]
        },
        {
          headers: { 'Content-Type': 'application/json' }
        }
      );

      const responseText = res.data.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!responseText) {
        throw new HttpsError("internal", "لم يتم استلام رد صالح من نموذج الذكاء الاصطناعي");
      }

      let cleanedJson = responseText.replace(/```(?:json)?/g, "").replace(/```/g, "").trim();
      const parsedData = JSON.parse(cleanedJson);

      return parsedData;

    } catch (e) {
      const errorMsg = e.response?.data?.error?.message || e.message;
      console.error("AI Invoice Error:", errorMsg);
      throw new HttpsError("internal", errorMsg);
    }
  }
);