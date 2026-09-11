import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../home/data/models/category_model.dart';
// 👈 تأكد من مسار الموديل حسب ترتيب مجلداتك

class AdminCategoriesRepo {
  final _firestore = FirebaseFirestore.instance.collection('categories');

  // جلب كل الأقسام للأدمن (حتى المخفية) ليعرضها ويرتبها
  Future<List<CategoryModel>> getAllCategories() async {
    final snapshot = await _firestore.orderBy('orderIndex').get();
    return snapshot.docs.map((doc) => CategoryModel.fromJson(doc.data(), doc.id)).toList();
  }

  // إضافة قسم جديد
  Future<void> addCategory(CategoryModel category) async {
    await _firestore.add(category.toJson());
  }

  // تغيير حالة القسم (إخفاء / إظهار) - Soft Delete
  Future<void> toggleCategoryStatus(String id, bool currentStatus) async {
    await _firestore.doc(id).update({'isActive': !currentStatus});
  }
}