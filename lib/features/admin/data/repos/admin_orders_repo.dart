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
    await _firestore.collection('orders').doc(orderId).update({
      'status': newStatus,
    });
  }
}