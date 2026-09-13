const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

exports.sendOrderUpdateNotification = onDocumentUpdated("orders/{orderId}", async (event) => {
    const newValue = event.data?.after.data();
    const previousValue = event.data?.before.data();

    if (!newValue || !previousValue) return null;
    if (newValue.status === previousValue.status) return null;

    const userId = newValue.userId;
    const status = newValue.status;
    const orderId = event.params.orderId;

    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) return console.log("User doc not found", userId);

    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return console.log("No FCM token for user", userId);

    let bodyMsg = `تم تحديث حالة طلبك إلى: ${status}`;
    if (status === 'Processing') bodyMsg = 'جاري تجهيز طلبك 📦';
    if (status === 'Shipped') bodyMsg = 'مندوبنا في الطريق إليك 🚚';
    if (status === 'Delivered') bodyMsg = 'شكراً لتسوقك من رامي ستور! ✅';
    if (status === 'Cancelled') bodyMsg = 'تم إلغاء الطلب ❌';

    const payload = {
        token: fcmToken,
        notification: {
            title: "تحديث حالة الطلب 📦",
            body: bodyMsg
        },
        data: {
            type: "order_update",
            orderId: orderId
        }
    };

    try {
        await messaging.send(payload);
        console.log('✅ FCM sent successfully for order', orderId);
    } catch (error) {
        console.error('❌ Error sending FCM:', error);
    }
    return null;
});