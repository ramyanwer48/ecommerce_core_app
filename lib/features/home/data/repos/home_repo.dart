import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart'; // مسار الاستدعاء الصحيح
import '../models/category_model.dart';
class HomeRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // 👈 الدالة الجديدة لجلب الأقسام من Firestore
  Future<List<CategoryModel>> getCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('categories')
        .where('isActive', isEqualTo: true) // نجلب الأقسام الفعالة فقط
        .orderBy('orderIndex') // الترتيب حسب ما يحدده الأدمن
        .get();

    return snapshot.docs
        .map((doc) => CategoryModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<List<ProductModel>> getProducts() async {
    try {
      // 👈 التعديل الجوهري هنا: فلترة المنتجات من السيرفر مباشرة
      final QuerySnapshot snapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true) // جلب المنتجات المتاحة فقط
          .get();

      List<ProductModel> products = snapshot.docs.map((doc) {
        return ProductModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      return products;
    } catch (e) {
      throw Exception('فشل في جلب المنتجات: $e');
    }
  }
}