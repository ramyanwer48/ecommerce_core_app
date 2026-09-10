import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart'; // مسار الاستدعاء الصحيح

class HomeRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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