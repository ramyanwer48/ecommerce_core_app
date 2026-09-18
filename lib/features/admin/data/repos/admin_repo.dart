import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart';

class AdminRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // دالة لرفع الصورة لفايربيز وجلب الرابط السحابي الخاص بها
  Future<String> uploadProductImage(File imageFile) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${basename(imageFile.path)}';
      Reference ref = _storage.ref().child('products_images/$fileName');
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('فشل رفع الصورة: $e');
    }
  }

  // 🌟 دالة إضافة المنتج ودعم نظام الدفعات (FIFO Batches)
  Future<void> addProduct({
    required String name,
    required double price,
    required double costPrice, // سعر التكلفة للدفعة الأولى
    required String category,
    required String description,
    required String imageUrl,
    required List<String> images,
    required List<String> variations,
    required bool inStock,
    required int stockQuantity,
  }) async {

    // تكوين "أول دفعة" للمنتج الجديد بناءً على تكلفة الشراء
    final initialBatch = {
      'batchId': 'batch_${DateTime.now().millisecondsSinceEpoch}',
      'quantity': stockQuantity,
      'costPrice': costPrice,
      'dateAdded': Timestamp.now(),
    };

    await _firestore.collection('products').add({
      'name': name,
      'price': price, // سعر البيع الثابت للعميل في الواجهة
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'images': images,
      'variations': variations,
      'inStock': stockQuantity > 0,
      'isActive': true,
      'stockQuantity': stockQuantity, // إجمالي المخزون
      'batches': [initialBatch], // حقن الدفعة الأولى
    });
  }

  // 1. إخفاء منتج (Soft Delete)
  Future<void> deleteProduct(String productId) async {
    await _firestore.collection('products').doc(productId).update({
      'isActive': false,
    });
  }

  // 🌟 تحديث سعر البيع الموحد للمنتج (في المستند الرئيسي فقط)
  Future<void> updateProductPrice(String productId, double newPrice) async {
    await _firestore.collection('products').doc(productId).update({
      'price': newPrice,
    });
  }

  // 🌟 دالة تحديث حالة الطلب وإرجاع المخزون (في حال الإلغاء) بنظام الدفعات (Returns FIFO Reversal)
  Future<void> updateOrderStatusAndRestoreStock({
    required String orderId,
    required String newStatus,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);

    await _firestore.runTransaction((transaction) async {
      // 1. جلب بيانات الطلب
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) throw Exception('الطلب غير موجود');

      final orderData = orderSnap.data() as Map<String, dynamic>;
      final String oldStatus = orderData['status'] ?? '';
      final List<dynamic> items = orderData['items'] ?? [];

      // 2. إذا تم تغيير الحالة إلى "Cancelled" (أو "ملغي") ولم تكن ملغية من قبل، نقوم بإرجاع المنتجات للمخزن
      if (newStatus.toLowerCase() == 'cancelled' && oldStatus.toLowerCase() != 'cancelled') {
        for (var item in items) {
          final String productId = item['productId'];
          final int quantityToRestore = item['quantity'] ?? 0;
          final double totalCost = (item['totalCost'] ?? 0.0).toDouble();

          // حساب متوسط التكلفة للقطعة الواحدة المرتجعة
          final double unitCostPrice = quantityToRestore > 0 ? (totalCost / quantityToRestore) : 0.0;

          final productRef = _firestore.collection('products').doc(productId);
          final productSnap = await transaction.get(productRef);

          if (productSnap.exists) {
            final productData = productSnap.data() as Map<String, dynamic>;
            List<dynamic> batches = productData['batches'] ?? [];

            // تكوين دفعة مرتجع جديدة بتكلفتها الأصلية
            final returnBatch = {
              'batchId': 'return_batch_${DateTime.now().millisecondsSinceEpoch}',
              'quantity': quantityToRestore,
              'costPrice': unitCostPrice,
              'dateAdded': Timestamp.now(),
            };

            batches.add(returnBatch);

            int currentStockQty = productData['stockQuantity'] ?? 0;
            int newStockQty = currentStockQty + quantityToRestore;

            // تحديث مخزون المنتج وإعادة حقن دفعة المرتجع داخل الـ batches
            transaction.update(productRef, {
              'batches': batches,
              'stockQuantity': newStockQty,
              'inStock': newStockQty > 0,
            });
          }
        }
      }

      // 3. تحديث حالة الطلب أياً كانت في النهاية
      transaction.update(orderRef, {
        'status': newStatus,
      });
    });
  }
}