import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class HomeRepo {
  // تعريف نسخة الفايربيز التي سنحقنها لاحقاً
  final FirebaseFirestore _firestore;

  HomeRepo(this._firestore);

  // دالة لجلب جميع المنتجات من قاعدة البيانات
  Future<List<ProductModel>> getProducts() async {
    try {
      // الاتصال بـ Firebase والذهاب إلى مجلد (collection) اسمه 'products'
      final snapshot = await _firestore.collection('products').get();

      // تحويل البيانات القادمة من السحابة إلى قائمة (List) من الـ ProductModel
      return snapshot.docs
          .map((doc) => ProductModel.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      // في حالة فشل الاتصال، نطبع الخطأ للمبرمج ونعيد قائمة فارغة
      print('Error fetching products: $e');
      return [];
    }
  }
}