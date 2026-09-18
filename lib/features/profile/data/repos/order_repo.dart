import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_model.dart';

class OrderRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<OrderModel>> getUserOrders() async {
    try {
      final userId = _auth.currentUser?.uid;

      if (userId == null) {
        throw Exception('يجب تسجيل الدخول لعرض الطلبات');
      }

      // 🧠 جلب طلبات المستخدم الحالي فقط بدون orderBy لمنع مشاكل الـ Indexes في فايربيز
      final snapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();

      List<OrderModel> orders = snapshot.docs
          .map((doc) => OrderModel.fromJson(doc.data(), doc.id))
          .toList();

      // 🧠 ترتيب الطلبات محلياً في التطبيق من الأحدث للأقدم (حسب التاريخ أو رقم الطلب)
      orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

      return orders;
    } catch (e) {
      throw Exception('فشل جلب طلبات المستخدم: $e');
    }
  }

  // 🧠 دالة إلغاء الطلب من طرف العميل مع استرجاع المخزون بالأسعار الدقيقة (FIFO Reversal)
  Future<void> cancelOrder(String orderId) async {
    final orderRef = _firestore.collection('orders').doc(orderId);

    await _firestore.runTransaction((transaction) async {
      // 1. مرحلة القراءات أولاً (Reads First)
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) throw Exception('الطلب غير موجود');

      final orderData = orderSnap.data() as Map<String, dynamic>;
      final String currentStatus = orderData['status'] ?? '';

      // تأمين إضافي: لا يمكن الإلغاء إلا لو كان قيد الانتظار
      if (currentStatus.toLowerCase() != 'pending') {
        throw Exception('عفواً، لا يمكن إلغاء الطلب في هذه المرحلة');
      }

      final List<dynamic> items = orderData['items'] ?? orderData['cartItems'] ?? [];
      Map<String, DocumentSnapshot> productSnaps = {};

      // قراءة كل المنتجات المرتبطة بالطلب
      for (var item in items) {
        final String productId = item['productId'] ?? item['id'] ?? '';
        if (productId.isEmpty) continue;
        final productRef = _firestore.collection('products').doc(productId);
        productSnaps[productId] = await transaction.get(productRef);
      }

      // 2. مرحلة الكتابة وإرجاع المخزون (Writes Second)
      for (var item in items) {
        final String productId = item['productId'] ?? item['id'] ?? '';
        final int quantityToRestore = item['quantity'] ?? 0;
        final List<dynamic> consumedBatches = item['consumedBatches'] ?? [];

        if (productId.isEmpty || quantityToRestore <= 0) continue;

        final productRef = _firestore.collection('products').doc(productId);
        final productSnap = productSnaps[productId];

        if (productSnap != null && productSnap.exists) {
          final productData = productSnap.data() as Map<String, dynamic>;
          List<dynamic> batches = productData['batches'] ?? [];

          // 👈 السر المحاسبي: إعادة كل قطعة لسعرها الحقيقي المخزن في consumedBatches
          if (consumedBatches.isNotEmpty) {
            for (var cb in consumedBatches) {
              batches.add({
                'batchId': 'customer_cancel_${cb['batchId'] ?? DateTime.now().millisecondsSinceEpoch}',
                'quantity': cb['quantity'],
                'costPrice': cb['costPrice'], // 👈 السعر الفعلي لكل قطعة
                'dateAdded': Timestamp.now(),
              });
            }
          } else {
            // مسار بديل (Fallback) للطلبات القديمة التي لم تمتلك consumedBatches
            final double totalCost = (item['totalCost'] ?? 0.0).toDouble();
            final double unitCostPrice = quantityToRestore > 0 ? (totalCost / quantityToRestore) : 0.0;

            batches.add({
              'batchId': 'customer_cancel_fallback_${DateTime.now().millisecondsSinceEpoch}',
              'quantity': quantityToRestore,
              'costPrice': unitCostPrice,
              'dateAdded': Timestamp.now(),
            });
          }

          int currentStockQty = productData['stockQuantity'] ?? 0;
          int newStockQty = currentStockQty + quantityToRestore;

          transaction.update(productRef, {
            'batches': batches,
            'stockQuantity': newStockQty,
            'inStock': newStockQty > 0,
          });
        }
      }

      // أخيرًا: تغيير حالة الطلب إلى ملغي
      transaction.update(orderRef, {'status': 'Cancelled'});
    });
  }
}