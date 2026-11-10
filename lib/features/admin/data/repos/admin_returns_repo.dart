import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminReturnsRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // 🚀 اعتماد المرتجع الشامل (المخزون، الخزينة تصفر، والأرباح تصفر تماماً) 🚀
  Future<void> approveReturn(String returnId, Map returnData) async {
    final String orderId = returnData['orderId']?.toString() ?? '';
    if (orderId.isEmpty) throw Exception('Order data is incomplete');

    final orderRef = _firestore.collection('orders').doc(orderId);
    final returnRef = _firestore.collection('return_requests').doc(returnId);

    await _firestore.runTransaction((transaction) async {
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) throw Exception('Original order not found');

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

      double totalCostPriceForRefund = 0.0;
      double subtotalForRefund = (orderData['subtotal'] ?? 0.0).toDouble();
      double discountForRefund = (orderData['discountAmount'] ?? 0.0).toDouble();

      for (var item in items) {
        Map itemMap = item as Map;
        final String productId = itemMap['productId']?.toString() ?? itemMap['id']?.toString() ?? '';
        final int quantityToRestore = (itemMap['quantity'] ?? 0).toInt();
        final List consumedBatches = (itemMap['consumedBatches'] ?? []) as List;

        if (productId.isEmpty || quantityToRestore <= 0) continue;

        final productSnap = productSnaps[productId];
        if (productSnap != null && productSnap.exists) {
          final productData = productSnap.data() as Map;
          List batches = List.from(productData['batches'] ?? []);

          if (consumedBatches.isNotEmpty) {
            for (var cb in consumedBatches) {
              Map cbMap = cb as Map;
              double cbCost = (cbMap['costPrice'] ?? 0.0).toDouble();
              int cbQty = (cbMap['quantity'] ?? 0).toInt();
              totalCostPriceForRefund += (cbCost * cbQty);

              batches.add({
                'batchId': cbMap['batchId'] ?? 'return_${DateTime.now().millisecondsSinceEpoch}',
                'quantity': cbQty,
                'costPrice': cbCost,
                'supplier': cbMap['supplier'] ?? 'Unknown',
                'supplierId': cbMap['supplierId'],
                'dateAdded': Timestamp.now(),
              });
            }
          } else {
            final double totalCost = (itemMap['totalCost'] ?? 0.0).toDouble();
            final double unitCostPrice = quantityToRestore > 0 ? (totalCost / quantityToRestore) : 0.0;
            totalCostPriceForRefund += totalCost;

            batches.add({
              'batchId': 'return_fallback_${DateTime.now().millisecondsSinceEpoch}',
              'quantity': quantityToRestore,
              'costPrice': unitCostPrice,
              'supplier': 'Unknown',
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
      final String paymentMethod = (orderData['paymentMethod'] ?? '').toString();
      final String paymentAccount = paymentMethod.contains('Card') || paymentMethod.contains('فيزا')
          ? 'بوابة الدفع (Paymob)'
          : 'الخزينة (كاش)';

      final ledgerRef = _firestore.collection('ledger_entries').doc();
      transaction.set(ledgerRef, {
        'id': ledgerRef.id,
        'orderId': orderId,
        'orderNumber': orderData['orderNumber'] ?? '',
        'userId': orderData['userId'] ?? '',
        'date': Timestamp.now(),
        'type': 'Refund',
        'entries': [
          {
            'account': paymentAccount,
            'debit': 0.0,
            'credit': totalRefund,
          },
          if (discountForRefund > 0)
            {
              'account': 'الخصم المسموح به (كوبونات)',
              'debit': 0.0,
              'credit': discountForRefund,
            },
          {
            'account': 'مردودات المبيعات',
            'debit': subtotalForRefund,
            'credit': 0.0,
          },
          {
            'account': 'تكلفة البضاعة المباعة',
            'debit': 0.0,
            'credit': totalCostPriceForRefund,
          },
          {
            'account': 'المخزون',
            'debit': totalCostPriceForRefund,
            'credit': 0.0,
          }
        ],
        'totalDebit': subtotalForRefund + totalCostPriceForRefund,
        'totalCredit': totalRefund + discountForRefund + totalCostPriceForRefund,
      });

      Map<String, dynamic> orderUpdate = {
        'status': 'Returned',
      };
      transaction.update(orderRef, orderUpdate);

      transaction.update(returnRef, {
        'status': 'Approved',
        'approvedAt': Timestamp.now(),
        'approvedBy': _auth.currentUser?.email,
      });
    });
  }

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