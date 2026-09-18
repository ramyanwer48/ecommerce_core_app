import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/coupon_model.dart';

class CheckoutRepo {
  final _firestore = FirebaseFirestore.instance;

  // 🔍 دالة التحقق من الكوبون السحرية
  Future<CouponModel?> validateCoupon(String code) async {
    final snapshot = await _firestore
        .collection('coupons')
        .where('code', isEqualTo: code)
        .where('isActive', isEqualTo: true)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return CouponModel.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);
    }
    return null;
  }

  // 🛒 دالة إنشاء الطلب بنظام الدفعات (FIFO) وتسجيل الدفعات المستهلكة بدقة
  Future<void> placeOrderWithFIFO({
    required String userId,
    required List<Map<String, dynamic>> cartItems,
    required double totalSellingAmount,
    required Map<String, dynamic> shippingAddress,
    required String paymentMethod,
  }) async {
    final orderRef = _firestore.collection('orders').doc();
    final counterRef = _firestore.collection('system').doc('orders_counter');

    await _firestore.runTransaction((transaction) async {
      // ==========================================
      // الخطوة الأولى: كل عمليات القراءة (Reads Only)
      // ==========================================
      final counterSnap = await transaction.get(counterRef);

      List<DocumentSnapshot> productSnaps = [];
      for (var item in cartItems) {
        final docRef = _firestore.collection('products').doc(item['productId']);
        final snap = await transaction.get(docRef);
        if (!snap.exists) {
          throw Exception('المنتج ${item['name'] ?? 'المطلوب'} لم يعد متوفراً');
        }
        productSnaps.add(snap);
      }

      // ==========================================
      // الخطوة الثانية: العمليات الحسابية ومعالجة البيانات
      // ==========================================
      int currentNumber = 1000;
      if (counterSnap.exists) {
        currentNumber = (counterSnap.data()?['lastNumber'] ?? 1000) + 1;
      }

      List<Map<String, dynamic>> finalOrderItems = [];
      double totalOrderCostPrice = 0.0;
      Map<DocumentSnapshot, Map<String, dynamic>> productsNewData = {};

      for (int i = 0; i < cartItems.length; i++) {
        var item = cartItems[i];
        var snap = productSnaps[i];
        var data = snap.data() as Map<String, dynamic>;

        int quantityToDeduct = item['quantity'];
        List<dynamic> batches = data['batches'] ?? [];

        // ترتيب الدفعات من الأقدم للأحدث (FIFO)
        batches.sort((a, b) {
          Timestamp tA = a['dateAdded'] ?? Timestamp.now();
          Timestamp tB = b['dateAdded'] ?? Timestamp.now();
          return tA.compareTo(tB);
        });

        List<Map<String, dynamic>> updatedBatches = [];
        List<Map<String, dynamic>> consumedBatches = []; // 👈 السر هنا: تسجيل الدفعات بالأسعار الدقيقة
        double itemTotalCost = 0.0;
        int remainingToDeduct = quantityToDeduct;

        for (var b in batches) {
          Map<String, dynamic> batchData = Map<String, dynamic>.from(b);
          int batchQty = batchData['quantity'];
          double batchCost = (batchData['costPrice'] ?? 0.0).toDouble();

          if (remainingToDeduct > 0) {
            if (batchQty > remainingToDeduct) {
              batchData['quantity'] = batchQty - remainingToDeduct;
              itemTotalCost += (remainingToDeduct * batchCost);

              consumedBatches.add({
                'quantity': remainingToDeduct,
                'costPrice': batchCost,
                'batchId': batchData['batchId'] ?? 'batch_${DateTime.now().millisecondsSinceEpoch}',
              });

              remainingToDeduct = 0;
              updatedBatches.add(batchData);
            } else {
              itemTotalCost += (batchQty * batchCost);

              consumedBatches.add({
                'quantity': batchQty,
                'costPrice': batchCost,
                'batchId': batchData['batchId'] ?? 'batch_${DateTime.now().millisecondsSinceEpoch}',
              });

              remainingToDeduct -= batchQty;
            }
          } else {
            updatedBatches.add(batchData);
          }
        }

        if (remainingToDeduct > 0) {
          throw Exception('الكمية المطلوبة من ${data['name']} أكبر من المتوفر في المخزن حالياً!');
        }

        finalOrderItems.add({
          'productId': item['productId'],
          'name': data['name'],
          'quantity': quantityToDeduct,
          'unitPrice': item['price'],
          'totalCost': itemTotalCost,
          'consumedBatches': consumedBatches, // 👈 حفظ الأسعار المحاسبية داخل كل منتج في الطلب
          'imageUrl': data['imageUrl'] ?? '',
        });

        totalOrderCostPrice += itemTotalCost;

        int currentStockQty = data['stockQuantity'] ?? 0;
        int newStockQty = currentStockQty - quantityToDeduct;

        productsNewData[snap] = {
          'batches': updatedBatches,
          'stockQuantity': newStockQty,
          'inStock': newStockQty > 0,
        };
      }

      // ==========================================
      // الخطوة الثالثة: كل عمليات الكتابة والتحديث (Writes Only)
      // ==========================================
      transaction.set(counterRef, {'lastNumber': currentNumber}, SetOptions(merge: true));

      productsNewData.forEach((snap, updateData) {
        transaction.update(snap.reference, updateData);
      });

      transaction.set(orderRef, {
        'id': orderRef.id,
        'orderNumber': currentNumber,
        'userId': userId,
        'items': finalOrderItems,
        'totalPrice': totalSellingAmount,
        'totalAmount': totalSellingAmount,
        'totalCostPrice': totalOrderCostPrice,
        'status': 'Pending',
        'phone': shippingAddress['phone'] ?? 'غير متوفر',
        'address': shippingAddress['address'] ?? 'غير متوفر',
        'shippingAddress': shippingAddress,
        'paymentMethod': paymentMethod,
        'orderDate': Timestamp.now(),
        'createdAt': Timestamp.now(),
      });
    });
  }
}