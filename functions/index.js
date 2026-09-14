const functions = require("firebase-functions/v1"); // 👈 التعديل هنا (إضافة /v1)
const admin = require("firebase-admin");
const axios = require("axios");

if (!admin.apps.length) {
  admin.initializeApp();
}

// 1. دالة الإشعارات الفورية عند تغيير حالة الطلب
exports.sendNotificationOnStatusChange = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const newValue = change.after.data();
    const previousValue = change.before.data();

    if (newValue.status !== previousValue.status) {
      try {
        const userDoc = await admin.firestore().collection('users').doc(newValue.userId).get();
        const fcmToken = userDoc.data().fcmToken;

        if (fcmToken) {
          const payload = {
            notification: {
              title: 'تحديث حالة الطلب 📦',
              body: `تم تحديث حالة طلبك إلى: ${newValue.status}`,
            }
          };
          await admin.messaging().sendToDevice(fcmToken, payload);
          console.log(`Notification sent to ${newValue.userId} for status ${newValue.status}`);
        }
      } catch (error) {
        console.error("Error sending notification:", error);
      }
    }
  });

// 2. دالة إنشاء الطلب والدفع الآمن باستخدام Paymob (Zero-Trust)
exports.createSecurePaymobOrder = functions
  .runWith({ secrets: ["PAYMOB_API_KEY"] })
  .https.onCall(async (data, context) => {
    // حماية: التأكد أن المستخدم مسجل دخول
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول لإتمام الدفع"
      );
    }

    const userId = context.auth.uid;
    const { totalAmount, billingData, items, address, phone } = data;

    // سحب المفتاح السري من خزنة فايربيز (لا يمكن للهاكر الوصول إليه)
    const apiKey = process.env.PAYMOB_API_KEY;

    // ضع رقم الـ Integration ID الخاص بك هنا (رقم عام وليس سري)
    const integrationId = "ضع_رقم_الانتجريشن_هنا";

    try {
      // إنشاء الطلب في Firestore بحالة Pending لحماية المعاملة
      const orderRef = admin.firestore().collection("orders").doc();
      await orderRef.set({
        id: orderRef.id,
        userId: userId,
        phone: phone,
        address: address,
        status: "Pending",
        totalPrice: totalAmount,
        items: items,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // توثيق السيرفر مع بايموب
      const authRes = await axios.post("https://accept.paymob.com/api/auth/tokens", {
        api_key: apiKey
      });
      const token = authRes.data.token;

      // تسجيل الطلب في بايموب
      const orderRes = await axios.post("https://accept.paymob.com/api/ecommerce/orders", {
        auth_token: token,
        delivery_needed: "false",
        amount_cents: Math.round(totalAmount * 100),
        currency: "EGP",
        items: [],
      });
      const paymobOrderId = orderRes.data.id;

      // استخراج مفتاح الدفع
      const keyRes = await axios.post("https://accept.paymob.com/api/acceptance/payment_keys", {
        auth_token: token,
        amount_cents: Math.round(totalAmount * 100),
        expiration: 3600,
        order_id: paymobOrderId,
        billing_data: billingData,
        currency: "EGP",
        integration_id: integrationId
      });

      // إرجاع مفتاح الدفع ورقم الطلب للموبايل لفتح الـ WebView فقط
      return {
        paymentToken: keyRes.data.token,
        orderId: orderRef.id
      };

    } catch (error) {
      console.error("❌ حدث خطأ في الدفع:", error.message);
      throw new functions.https.HttpsError("internal", "فشل في تهيئة الدفع");
    }
  });