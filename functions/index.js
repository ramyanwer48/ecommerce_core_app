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

      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${apiKey}`;

      const res = await axios.post(
        url,
        {
          system_instruction: { parts: [{ text: systemInstruction }] },
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
// 4. دالة تحليل الفواتير بالذكاء الاصطناعي (AI Invoice Parser) - معدلة بالصيغة الصحيحة REST API
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
      Extract the supplier name, invoice number, and list of items.
      CRITICAL RULE: Translate and standardize all item names strictly into ENGLISH to match our inventory database.
      Return the response ONLY as a valid JSON object with this exact structure, with no extra text or markdown outside the JSON:
      {
        "supplier": "Supplier Name in English",
        "invoice_no": "Invoice Number",
        "items": [
          {"name": "Standardized English Name", "qty": 1, "price": 100.0, "category": "Accessories"}
        ]
      }
      `;

      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

      const res = await axios.post(
        url,
        {
          system_instruction: {
            parts: [{ text: systemInstruction }]
          },
          contents: [
            {
              parts: [
                { text: "Extract invoice details from this image accurately and return only JSON." },
                {
                  inline_data: { // 👈 التصحيح الهندسي: استخدام inline_data بدل inlineData للـ REST API
                    mime_type: "image/jpeg", // 👈 التصحيح الهندسي: استخدام mime_type بدل mimeType للـ REST API
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

      let cleanedJson = responseText.replace(/```json/g, "").replace(/```/g, "").trim();
      const parsedData = JSON.parse(cleanedJson);

      return parsedData;

    } catch (e) {
      const errorMsg = e.response?.data?.error?.message || e.message;
      console.error("AI Invoice Error:", errorMsg);
      throw new HttpsError("internal", errorMsg);
    }
  }
);