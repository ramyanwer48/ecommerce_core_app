const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

exports.askNaaseh = onCall(
  { secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    // في الجيل الثاني، البيانات تأتي عبر request.data
    const userPrompt = request.data?.prompt;
    if (!userPrompt) {
      throw new HttpsError("invalid-argument", "برجاء إدخال السؤال");
    }

    const apiKey = process.env.GEMINI_API_KEY ? process.env.GEMINI_API_KEY.trim() : '';

    try {
      const db = admin.firestore();

      // سحب المنتجات والأسعار من الكتالوج
      const productSnap = await db.collection('products').limit(15).get();
      const catalogContext = productSnap.docs
        .map(d => `${d.data().name} بسعر ${d.data().price} ج.م`)
        .join(' | ');

      // توجيهات النظام لفهم المنتجات والميزانية
      const systemInstruction = `
      أنت "ناصح"، مساعد مبيعات ذكي وودود لمتجر Ramy Store.
      الكاتالوج الحالي للمتجر بالأسعار: ${catalogContext}.
      مهامك الأساسية:
      1. إذا سأل العميل عن منتج معين، أعطه تفاصيله وسعره بدقة.
      2. إذا ذكر العميل ميزانية مالية محددة (مثلاً: معي مبلغ كذا)، اقترح عليه المنتج المناسب لهذه الميزانية تماماً، أو مجموعة منتجات (كومبو) لا تتجاوز هذا المبلغ.
      3. كن دقيقاً، مختصرًا، وتحدث باللغة العربية الفصحى فقط.
      `;

      // استخدام موديل gemini-3.6-flash الأحدث
      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${apiKey}`;

      const res = await axios.post(
        url,
        {
          system_instruction: { parts: [{ text: systemInstruction }] },
          contents: [{ parts: [{ text: userPrompt }] }]
        },
        {
          headers: {
            'Content-Type': 'application/json'
          }
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
// دالة إرسال إشعار تلقائي للعميل عند تغير حالة الطلب
// =======================================================
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");

exports.sendOrderUpdateNotification = onDocumentUpdated("orders/{orderId}", async (event) => {
    const newValue = event.data.after.data();
    const previousValue = event.data.before.data();

    // 1. لا نرسل الإشعار إلا إذا تغيرت حالة الطلب فقط
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
      // 2. جلب التوكن الخاص بالعميل من كوليكشن users
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log(`لا يوجد fcmToken للعميل: ${userId}`);
        return null;
      }

      // 3. تحديد نص الرسالة بناءً على الحالة
      let bodyMsg = `تم تحديث حالة طلبك إلى: ${newStatus}`;
      if (newStatus.toLowerCase() === 'processing') bodyMsg = 'طلبك قيد التجهيز الآن 📦';
      if (newStatus.toLowerCase() === 'shipped') bodyMsg = 'مندوبنا في الطريق إليك 🚚';
      if (newStatus.toLowerCase() === 'delivered') bodyMsg = 'شكراً لتسوقك من رامي ستور! نأمل أن يعجبك المنتج ✅';
      if (newStatus.toLowerCase() === 'cancelled') bodyMsg = 'تم إلغاء طلبك، وإرجاع المبالغ لحسابك ❌';

      // 4. تجهيز الإشعار مع الـ Deep Linking
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

      // 5. إرسال الإشعار
      const response = await admin.messaging().send(payload);
      console.log("✅ تم إرسال الإشعار بنجاح:", response);
      return response;

    } catch (error) {
      console.error("❌ فشل إرسال الإشعار:", error);
      return null;
    }
});