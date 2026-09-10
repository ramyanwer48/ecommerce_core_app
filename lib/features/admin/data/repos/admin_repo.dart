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
      // استخراج اسم الصورة وإضافة وقت عشان الأسماء متتكررش
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${basename(imageFile.path)}';

      // تحديد مسار الحفظ في فايربيز (داخل مجلد products_images)
      Reference ref = _storage.ref().child('products_images/$fileName');

      // رفع الصورة
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      // الحصول على الرابط القابل للعرض
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('فشل رفع الصورة: $e');
    }
  }

  // دالة إضافة المنتج
  Future<void> addProduct({
    required String name,
    required double price,
    required String category,
    required String description,
    required String imageUrl,
    required List<String> images,
    required List<String> variations,
    required bool inStock,
  }) async {
    await _firestore.collection('products').add({
      'name': name,
      'price': price,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'images': images,
      'variations': variations,
      'inStock': inStock,
      'isActive': true, // 👈 تم إضافة هذه القيمة لضمان أن المنتج الجديد متاح دائماً
    });
  }

  // 1. إخفاء منتج (Soft Delete) بدلاً من الحذف النهائي 👈 (التعديل الجوهري هنا)
  Future<void> deleteProduct(String productId) async {
    await _firestore.collection('products').doc(productId).update({
      'isActive': false,
    });
  }

  // 2. تعديل السعر
  Future<void> updateProductPrice(String productId, double newPrice) async {
    await _firestore.collection('products').doc(productId).update({
      'price': newPrice,
    });
  }
}