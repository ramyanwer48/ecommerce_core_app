import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/coupon_model.dart';

class CheckoutRepo {
  final _firestore = FirebaseFirestore.instance;

  // 🔍 دالة التحقق من الكوبون
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

  // 🛒 دالة إنشاء الطلب بنظام الدفعات (FIFO) وتسجيل القيود المحاسبية
  Future<void> placeOrderWithFIFO({
    required String userId,
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    required double discountAmount,
    required double totalSellingAmount,
    required Map<String, dynamic> shippingAddress,
    required String paymentMethod,
  }) async {
    final orderRef = _firestore.collection('orders').doc();
    final counterRef = _firestore.collection('system').doc('orders_counter');
    final ledgerRef = _firestore.collection('ledger_entries').doc();

    await _firestore.runTransaction((transaction) async {
      // 1. كل عمليات القراءة
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

      // 2. العمليات الحسابية
      // 👈 تم إضافة التحويل الآمن لـ int هنا
      int currentNumber = 1000;
      if (counterSnap.exists) {
        currentNumber = ((counterSnap.data()?['lastNumber'] as num?)?.toInt() ?? 1000) + 1;
      }

      List<Map<String, dynamic>> finalOrderItems = [];
      double totalOrderCostPrice = 0.0;
      Map<DocumentSnapshot, Map<String, dynamic>> productsNewData = {};

      for (int i = 0; i < cartItems.length; i++) {
        var item = cartItems[i];
        var snap = productSnaps[i];
        var data = snap.data() as Map<String, dynamic>;

        // 👈 تم إضافة التحويل الآمن لـ int هنا
        int quantityToDeduct = (item['quantity'] as num).toInt();
        List<dynamic> batches = data['batches'] ?? [];

        batches.sort((a, b) {
          Timestamp tA = a['dateAdded'] ?? Timestamp.now();
          Timestamp tB = b['dateAdded'] ?? Timestamp.now();
          return tA.compareTo(tB);
        });

        List<Map<String, dynamic>> updatedBatches = [];
        List<Map<String, dynamic>> consumedBatches = [];
        double itemTotalCost = 0.0;
        int remainingToDeduct = quantityToDeduct;

        for (var b in batches) {
          Map<String, dynamic> batchData = Map<String, dynamic>.from(b);
          // 👈 تم إضافة التحويل الآمن لـ int هنا
          int batchQty = (batchData['quantity'] as num).toInt();
          double batchCost = (batchData['costPrice'] as num?)?.toDouble() ?? 0.0;

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
          'unitPrice': (item['price'] as num).toDouble(),
          'totalCost': itemTotalCost,
          'consumedBatches': consumedBatches,
          'imageUrl': data['imageUrl'] ?? '',
        });

        totalOrderCostPrice += itemTotalCost;

        // 👈 تم إضافة التحويل الآمن لـ int هنا
        int currentStockQty = (data['stockQuantity'] as num?)?.toInt() ?? 0;
        int newStockQty = currentStockQty - quantityToDeduct;

        productsNewData[snap] = {
          'batches': updatedBatches,
          'stockQuantity': newStockQty,
          'inStock': newStockQty > 0,
        };
      }

      // 3. كل عمليات الكتابة
      transaction.set(counterRef, {'lastNumber': currentNumber}, SetOptions(merge: true));

      productsNewData.forEach((snap, updateData) {
        transaction.update(snap.reference, updateData);
      });

      // تسجيل وثيقة الطلب
      transaction.set(orderRef, {
        'id': orderRef.id,
        'orderNumber': currentNumber,
        'userId': userId,
        'items': finalOrderItems,
        'subtotal': subtotal,
        'discountAmount': discountAmount,
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

      // القيد المحاسبي المزدوج (Double-Entry Bookkeeping)
      transaction.set(ledgerRef, {
        'id': ledgerRef.id,
        'orderId': orderRef.id,
        'orderNumber': currentNumber,
        'userId': userId,
        'date': Timestamp.now(),
        'type': 'Sales',
        'entries': [
          {
            'account': paymentMethod == 'Online Card' ? 'بوابة الدفع (Paymob)' : 'الخزينة (كاش)',
            'debit': totalSellingAmount,
            'credit': 0.0,
          },
          if (discountAmount > 0)
            {
              'account': 'الخصم المسموح به (كوبونات)',
              'debit': discountAmount,
              'credit': 0.0,
            },
          {
            'account': 'إيرادات المبيعات',
            'debit': 0.0,
            'credit': subtotal,
          },
          {
            'account': 'تكلفة البضاعة المباعة',
            'debit': totalOrderCostPrice,
            'credit': 0.0,
          },
          {
            'account': 'المخزون',
            'debit': 0.0,
            'credit': totalOrderCostPrice,
          }
        ],
        'totalDebit': totalSellingAmount + discountAmount + totalOrderCostPrice,
        'totalCredit': subtotal + totalOrderCostPrice,
      });
    });
  }

  // 🔄 دالة الإلغاء الشاملة (إرجاع المخزون + القيد المحاسبي العكسي)
  Future<void> cancelOrderWithFIFORefund(String orderId) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final ledgerRef = _firestore.collection('ledger_entries').doc();

    await _firestore.runTransaction((transaction) async {
      // 1. قراءة بيانات الطلب
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) throw Exception('الطلب غير موجود');
      final orderData = orderSnap.data() as Map<String, dynamic>;

      if (orderData['status'] == 'Cancelled') {
        throw Exception('الطلب ملغي بالفعل');
      }

      final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);

      Map<String, DocumentSnapshot> productSnaps = {};
      for (var item in items) {
        final productId = item['productId'];
        final pSnap = await transaction.get(_firestore.collection('products').doc(productId));
        productSnaps[productId] = pSnap;
      }

      // 3. معالجة الإرجاع بنظام FIFO
      for (var item in items) {
        final productId = item['productId'];
        final consumedBatches = List<Map<String, dynamic>>.from(item['consumedBatches'] ?? []);
        // 👈 تم إضافة التحويل الآمن لـ int هنا
        final quantityToRestore = (item['quantity'] as num?)?.toInt() ?? 0;

        final pSnap = productSnaps[productId];
        if (pSnap != null && pSnap.exists) {
          final pData = pSnap.data() as Map<String, dynamic>;
          List<dynamic> batches = pData['batches'] ?? [];

          for (var cb in consumedBatches) {
            batches.add({
              'batchId': cb['batchId'],
              'quantity': (cb['quantity'] as num).toInt(), // 👈 تحويل آمن
              'costPrice': (cb['costPrice'] as num).toDouble(), // 👈 تحويل آمن
              'dateAdded': Timestamp.now(),
            });
          }

          // 👈 تم إضافة التحويل الآمن لـ int هنا
          int currentStock = (pData['stockQuantity'] as num?)?.toInt() ?? 0;
          int newStock = currentStock + quantityToRestore;

          transaction.update(pSnap.reference, {
            'batches': batches,
            'stockQuantity': newStock,
            'inStock': newStock > 0,
          });
        }
      }

      // 4. تحديث حالة الطلب
      transaction.update(orderRef, {'status': 'Cancelled'});

      // 5. إنشاء القيد المحاسبي المزدوج العكسي
      final totalSellingAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final totalCostPrice = (orderData['totalCostPrice'] as num?)?.toDouble() ?? 0.0;
      final discountAmount = (orderData['discountAmount'] as num?)?.toDouble() ?? 0.0;
      final subtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;
      final paymentMethod = (orderData['paymentMethod'] ?? '').toString();

      final String paymentAccount = paymentMethod.contains('Card') || paymentMethod.contains('فيزا')
          ? 'بوابة الدفع (Paymob)'
          : 'الخزينة (كاش)';

      transaction.set(ledgerRef, {
        'id': ledgerRef.id,
        'orderId': orderId,
        'orderNumber': orderData['orderNumber'],
        'userId': orderData['userId'],
        'date': Timestamp.now(),
        'type': 'Refund',
        'entries': [
          {
            'account': paymentAccount,
            'debit': 0.0,
            'credit': totalSellingAmount,
          },
          if (discountAmount > 0)
            {
              'account': 'الخصم المسموح به (كوبونات)',
              'debit': 0.0,
              'credit': discountAmount,
            },
          {
            'account': 'مردودات المبيعات',
            'debit': subtotal,
            'credit': 0.0,
          },
          {
            'account': 'تكلفة البضاعة المباعة',
            'debit': 0.0,
            'credit': totalCostPrice,
          },
          {
            'account': 'المخزون',
            'debit': totalCostPrice,
            'credit': 0.0,
          }
        ],
        'totalDebit': subtotal + totalCostPrice,
        'totalCredit': totalSellingAmount + discountAmount + totalCostPrice,
      });
    });
  }
}