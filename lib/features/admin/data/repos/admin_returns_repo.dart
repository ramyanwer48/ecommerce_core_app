import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminReturnsRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // جلب كل طلبات المرتجعات المعلقة (بدون أقواس متداخلة لتجنب مشاكل النسخ)
  Future<dynamic> getPendingReturns() async {
    try {
      final snap = await _firestore
          .collection('return_requests')
          .where('status', isEqualTo: 'Pending Approval')
          .orderBy('requestDate', descending: true)
          .get();

      return snap.docs.map((doc) {
        Map data = doc.data() as Map;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('فشل جلب المرتجعات: $e');
    }
  }

  // جلب سجل المرتجعات المكتملة (المعتمدة أو المرفوضة) للأرشفة
  Future<dynamic> getCompletedReturnsLog() async {
    try {
      final snap = await _firestore
          .collection('return_requests')
          .where('status', whereIn: ['Approved', 'Rejected'])
          .orderBy('requestDate', descending: true)
          .get();

      return snap.docs.map((doc) {
        Map data = doc.data() as Map;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('فشل جلب سجل المرتجعات: $e');
    }
  }

  // اعتماد المرتجع الشامل (المخزون والخزينة والأرباح)
  Future<void> approveReturn(String returnId, Map returnData) async {
    final String orderId = returnData['orderId']?.toString() ?? '';
    if (orderId.isEmpty) throw Exception('بيانات الطلب غير مكتملة');

    final orderRef = _firestore.collection('orders').doc(orderId);
    final returnRef = _firestore.collection('return_requests').doc(returnId);

    await _firestore.runTransaction((transaction) async {
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) throw Exception('الطلب الأصلي غير موجود في النظام');

      final orderData = orderSnap.data() as Map;
      final List items = (orderData['items'] ?? orderData['cartItems'] ?? []) as List;

      Map productSnaps = {};
      for (var item in items) {
        Map itemMap = item as Map;
        final String productId = itemMap['productId']?.toString() ?? itemMap['id']?.toString() ?? '';
        if (productId.isNotEmpty) {
          productSnaps[productId] = await transaction.get(_firestore.collection('products').doc(productId));
        }
      }

      for (var item in items) {
        Map itemMap = item as Map;
        final String productId = itemMap['productId']?.toString() ?? itemMap['id']?.toString() ?? '';
        final int quantityToRestore = (itemMap['quantity'] ?? 0).toInt();
        final List consumedBatches = (itemMap['consumedBatches'] ?? []) as List;

        if (productId.isEmpty || quantityToRestore <= 0) continue;

        final productSnap = productSnaps[productId];
        if (productSnap != null && productSnap.exists) {
          final productData = productSnap.data() as Map;
          List batches = (productData['batches'] ?? []) as List;

          if (consumedBatches.isNotEmpty) {
            for (var cb in consumedBatches) {
              Map cbMap = cb as Map;
              batches.add({
                'batchId': 'return_${cbMap['batchId'] ?? DateTime.now().millisecondsSinceEpoch}',
                'quantity': (cbMap['quantity'] ?? 0).toInt(),
                'costPrice': (cbMap['costPrice'] ?? 0.0).toDouble(),
                'dateAdded': Timestamp.now(),
              });
            }
          } else {
            final double totalCost = (itemMap['totalCost'] ?? 0.0).toDouble();
            final double unitCostPrice = quantityToRestore > 0 ? (totalCost / quantityToRestore) : 0.0;
            batches.add({
              'batchId': 'return_fallback_${DateTime.now().millisecondsSinceEpoch}',
              'quantity': quantityToRestore,
              'costPrice': unitCostPrice,
              'dateAdded': Timestamp.now(),
            });
          }

          int currentStockQty = (productData['stockQuantity'] ?? 0).toInt();
          transaction.update(_firestore.collection('products').doc(productId), {
            'batches': batches,
            'stockQuantity': currentStockQty + quantityToRestore,
            'inStock': (currentStockQty + quantityToRestore) > 0,
          });
        }
      }

      final double totalRefund = (returnData['totalRefund'] ?? 0.0).toDouble();

      // 🚀 تسجيل حركة الخزينة والاسترداد في السجل المالي بشكل سليم ومتصل
      final ledgerRef = _firestore.collection('ledger_entries').doc();
      transaction.set(ledgerRef, {
        'id': ledgerRef.id,
        'type': 'refund',
        'amount': -totalRefund,
        'description': 'رد مبلغ لعميل - مرتجع طلب رقم ${returnData['orderNumber'] ?? ''}',
        'date': Timestamp.now(),
        'addedBy': _auth.currentUser?.email ?? 'System',
      });

      transaction.update(orderRef, {'status': 'Returned'});
      transaction.update(returnRef, {
        'status': 'Approved',
        'approvedAt': Timestamp.now(),
        'approvedBy': _auth.currentUser?.email,
      });
    });
  }

  // 3. رفض المرتجع
  Future<void> rejectReturn(String returnId, String orderId) async {
    await _firestore.runTransaction((transaction) async {
      final returnRef = _firestore.collection('return_requests').doc(returnId);
      final orderRef = _firestore.collection('orders').doc(orderId);

      transaction.update(returnRef, {
        'status': 'Rejected',
        'rejectedAt': Timestamp.now(),
        'rejectedBy': _auth.currentUser?.email,
      });

      transaction.update(orderRef, {'status': 'Delivered'});
    });
  }
}