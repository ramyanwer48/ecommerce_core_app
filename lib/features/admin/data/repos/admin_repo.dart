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

  // 🌟 التعديل هنا: دالة إضافة المنتج بقت تدعم نظام الدفعات (FIFO Batches)
  Future<void> addProduct({
    required String name,
    required double price,
    required String category,
    required String description,
    required String imageUrl,
    required List<String> images,
    required List<String> variations,
    required bool inStock,
    required int stockQuantity,
  }) async {

    // تكوين "أول دفعة" للمنتج الجديد
    final initialBatch = {
      'batchId': 'batch_${DateTime.now().millisecondsSinceEpoch}',
      'quantity': stockQuantity,
      'sellingPrice': price,
      'dateAdded': Timestamp.now(),
    };

    await _firestore.collection('products').add({
      'name': name,
      'price': price, // كمرجع احتياطي
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'images': images,
      'variations': variations,
      'inStock': stockQuantity > 0,
      'isActive': true,
      'stockQuantity': stockQuantity, // كمرجع للبحث
      'batches': [initialBatch], // 👈 حقن الدفعة الأولى هنا
    });
  }

  // 1. إخفاء منتج (Soft Delete)
  Future<void> deleteProduct(String productId) async {
    await _firestore.collection('products').doc(productId).update({
      'isActive': false,
    });
  }

  // 🌟 التعديل هنا: تعديل السعر الأساسي بيحدث أسعار الدفعات المتاحة حالياً
  Future<void> updateProductPrice(String productId, double newPrice) async {
    final doc = await _firestore.collection('products').doc(productId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    List<dynamic> rawBatches = data['batches'] ?? [];

    // اللف على الدفعات وتحديث سعر الدفعات اللي لسه فيها مخزون فقط
    List<Map<String, dynamic>> updatedBatches = rawBatches.map((b) {
      final batch = Map<String, dynamic>.from(b as Map);
      if (batch['quantity'] > 0) {
        batch['sellingPrice'] = newPrice;
      }
      return batch;
    }).toList();

    await _firestore.collection('products').doc(productId).update({
      'price': newPrice,
      'batches': updatedBatches,
    });
  }
}