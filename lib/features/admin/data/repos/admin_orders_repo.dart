import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../profile/data/models/order_model.dart';

class AdminOrdersRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. جلب كل الطلبات في المتجر (بدون orderBy مسبق لمنع مشاكل الـ Indexes)
  Future<List<OrderModel>> getAllOrders() async {
    try {
      final snapshot = await _firestore.collection('orders').get();

      List<OrderModel> orders = snapshot.docs
          .map((doc) => OrderModel.fromJson(doc.data(), doc.id))
          .toList();

      // ترتيب الطلبات محلياً من الأحدث للأقدم لضمان عدم حدوث أي مشاكل في فايربيز
      orders.sort((a, b) => b.id.compareTo(a.id));

      return orders;
    } catch (e) {
      throw Exception('فشل جلب الطلبات: $e');
    }
  }

  // 2. تحديث حالة الطلب وإرجاع المخزون في حالة الإلغاء بدقة محاسبية (FIFO Reversal)
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final orderRef = _firestore.collection('orders').doc(orderId);

    await _firestore.runTransaction((transaction) async {
      // ==========================================
      // 1. مرحلة القراءات أولاً (Reads First)
      // ==========================================
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) throw Exception('الطلب غير موجود');

      final orderData = orderSnap.data() as Map<String, dynamic>;
      final String oldStatus = orderData['status'] ?? '';
      final List<dynamic> items = orderData['items'] ?? orderData['cartItems'] ?? [];

      // خريطة لتخزين بيانات المنتجات والقراءات الخاصة بها مسبقاً لمنع خطأ الفايربيز
      Map<String, DocumentSnapshot> productSnaps = {};

      if (newStatus.toLowerCase() == 'cancelled' && oldStatus.toLowerCase() != 'cancelled') {
        for (var item in items) {
          final String productId = item['productId'] ?? item['id'] ?? '';
          if (productId.isEmpty) continue;

          final productRef = _firestore.collection('products').doc(productId);
          final productSnap = await transaction.get(productRef); // 👈 قراءة قبل أي كتابة
          productSnaps[productId] = productSnap;
        }
      }

      // ==========================================
      // 2. مرحلة الكتابة والتحديثات ثانياً (Writes Second)
      // ==========================================
      if (newStatus.toLowerCase() == 'cancelled' && oldStatus.toLowerCase() != 'cancelled') {
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
                  'batchId': 'return_${cb['batchId'] ?? DateTime.now().millisecondsSinceEpoch}',
                  'quantity': cb['quantity'],
                  'costPrice': cb['costPrice'], // 👈 السعر الفعلي لكل قطعة
                  'dateAdded': Timestamp.now(),
                });
              }
            } else {
              // مسار بديل (Fallback) لحماية الطلبات القديمة التي تمت قبل هذا التحديث
              final double totalCost = (item['totalCost'] ?? 0.0).toDouble();
              final double unitCostPrice = quantityToRestore > 0 ? (totalCost / quantityToRestore) : 0.0;

              batches.add({
                'batchId': 'return_batch_${DateTime.now().millisecondsSinceEpoch}',
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
      }

      // تحديث حالة الأوردر النهائية
      transaction.update(orderRef, {
        'status': newStatus,
      });
    });
  }
}