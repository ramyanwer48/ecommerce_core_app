import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../profile/data/models/order_model.dart'; // تأكد من مطابقة المسار لموديل الطلب الخاص بك

class AdminOrdersRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // جلب كل الطلبات في المتجر
  Future<List<OrderModel>> getAllOrders() async {
    final snapshot = await _firestore
        .collection('orders')
        .orderBy('orderDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => OrderModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  // تحديث حالة الطلب
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final orderRef = firestore.collection('orders').doc(orderId);

    // لو تغيير حالة عادية مش إلغاء، حدث وامشي
    if (newStatus != 'Cancelled') {
      await orderRef.update({'status': newStatus});
      return;
    }

    // 🔥 لو الحالة إلغاء (Cancelled)، لازم نعمل مرتجع مخزني بالسعر القديم 🔥
    final orderDoc = await orderRef.get();
    if (!orderDoc.exists) return;

    final orderData = orderDoc.data()!;
    if (orderData['status'] == 'Cancelled') return; // منع التكرار

    final List<dynamic> items = orderData['items'] ?? orderData['cartItems'] ?? [];

    WriteBatch batch = firestore.batch();
    batch.update(orderRef, {'status': newStatus}); // إلغاء الطلب

    // عمل مرتجع لكل منتج في الطلب
    for (var item in items) {
      final String productId = item['productId'] ?? item['id'] ?? '';
      final int quantity = item['quantity'] ?? 1;
      final double oldPrice = (item['price'] ?? 0.0).toDouble();

      if (productId.isEmpty) continue;

      final productRef = firestore.collection('products').doc(productId);

      // 👈 هنا بنصنع الشحنة المرتجعة بالسعر اللي العميل اشترى بيه زمان (مثلاً 300)
      final returnedBatch = {
        'batchId': 'return_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
        'quantity': quantity,
        'sellingPrice': oldPrice,
        'dateAdded': Timestamp.now(),
      };

      batch.update(productRef, {
        'batches': FieldValue.arrayUnion([returnedBatch]),
        'stockQuantity': FieldValue.increment(quantity),
        'stock': FieldValue.increment(quantity),
      });
    }

    await batch.commit(); // تنفيذ الإلغاء والمرتجع في خبطة واحدة
  }
}