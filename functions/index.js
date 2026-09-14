const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const axios = require("axios");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// 1. دالة الإشعارات الفورية عند تغيير حالة الطلب
exports.sendNotificationOnStatusChange = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const newValue = change.after.data();
    const previousValue = change.before.data();

    if (newValue.status !== previousValue.status) {
      try {
        const userDoc = await db.collection('users').doc(newValue.userId).get();
        const fcmToken = userDoc.data()?.fcmToken;

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
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول لإتمام الدفع"
      );
    }

    const userId = context.auth.uid;
    const { totalAmount, billingData, items, address, phone } = data;
    const apiKey = process.env.PAYMOB_API_KEY;
    const integrationId = "5911923"

    try {
      // إنشاء الطلب في Firestore بحالة Pending
      const orderRef = db.collection("orders").doc();
      await orderRef.set({
        id: orderRef.id,
        userId: userId,
        phone: phone,
        address: address,
        status: "Pending",
        totalPrice: totalAmount,
        items: items || [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // توثيق السيرفر مع بايموب
      const authRes = await axios.post("https://accept.paymob.com/api/auth/tokens", {
        api_key: apiKey
      });
      const token = authRes.data.token;

      // تسجيل الطلب في بايموب مع ربطه بـ merchant_order_id (رقم الطلب في فايربيز)
      const orderRes = await axios.post("https://accept.paymob.com/api/ecommerce/orders", {
        auth_token: token,
        delivery_needed: "false",
        amount_cents: Math.round(totalAmount * 100),
        currency: "EGP",
        merchant_order_id: orderRef.id, // 👈 الربط الجوهري للويب هوك
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

      return {
        paymentToken: keyRes.data.token,
        orderId: orderRef.id
      };

    } catch (error) {
      console.error("❌ حدث خطأ في الدفع:", error.response?.data || error.message);
      throw new functions.https.HttpsError("internal", "فشل في تهيئة الدفع");
    }
  });

// 3. دالة الويب هوك لاستقبال تأكيد الدفع من بايموب (Idempotent)
exports.paymobWebhook = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed");
    }

    const data = req.body;
    const obj = data.obj;

    if (!obj || !obj.id) {
      return res.status(400).send("Invalid payload");
    }

    const transactionId = obj.id.toString();
    const isSuccess = obj.success === true;
    const merchantOrderId = obj.order?.merchant_order_id; // استخراج ID الطلب في فايربيز

    console.log(`Paymob Webhook -> Tx: ${transactionId}, Success: ${isSuccess}, OrderId: ${merchantOrderId}`);

    const txRef = db.collection("processed_transactions").doc(transactionId);

    await db.runTransaction(async (transaction) => {
      const existingTx = await transaction.get(txRef);
      if (existingTx.exists) {
        console.log(`Transaction ${transactionId} already processed.`);
        return;
      }

      if (merchantOrderId) {
        const orderRef = db.collection("orders").doc(merchantOrderId);
        const orderDoc = await transaction.get(orderRef);

        if (orderDoc.exists) {
          const currentStatus = orderDoc.data().status;
          if (currentStatus === "Pending") {
            transaction.update(orderRef, {
              status: isSuccess ? "Paid" : "PaymentFailed",
              paymentTransactionId: transactionId,
              paidAt: isSuccess ? admin.firestore.FieldValue.serverTimestamp() : null,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`Order ${merchantOrderId} updated to ${isSuccess ? 'Paid' : 'PaymentFailed'}`);
          }
        } else {
          console.warn(`Order ${merchantOrderId} not found.`);
        }
      }

      transaction.set(txRef, {
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: isSuccess ? "Paid" : "Failed",
        merchantOrderId: merchantOrderId || null,
      });
    });

    return res.status(200).send("Webhook processed successfully");
  } catch (error) {
    console.error("Error processing Paymob webhook:", error);
    return res.status(500).send("Internal Server Error");
  }
});