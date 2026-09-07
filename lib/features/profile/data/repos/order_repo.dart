import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_model.dart';

class OrderRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<OrderModel>> getUserOrders() async {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      throw Exception('يجب تسجيل الدخول لعرض الطلبات');
    }

    // جلب طلبات المستخدم الحالي فقط، وترتيبها من الأحدث للأقدم بناءً على orderDate
    final snapshot = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('orderDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => OrderModel.fromJson(doc.data(), doc.id))
        .toList();
  }
}