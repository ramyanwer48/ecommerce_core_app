import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../checkout/data/models/coupon_model.dart'; // مسار الموديل الحالي
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCouponsRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // جلب كل الكوبونات
  Future<List<CouponModel>> getAllCoupons() async {
    final snapshot = await _firestore.collection('coupons').get();
    return snapshot.docs.map((doc) => CouponModel.fromJson(doc.data(), doc.id)).toList();
  }

  // إضافة كوبون جديد
  Future<void> addCoupon({required String code, required double discountPercentage}) async {
    // التأكد من عدم وجود الكوبون مسبقاً
    final existing = await _firestore.collection('coupons').where('code', isEqualTo: code).get();
    if (existing.docs.isNotEmpty) throw Exception('هذا الكوبون موجود مسبقاً!');

    await _firestore.collection('coupons').add({
      'code': code.toUpperCase().trim(),
      'discountPercentage': discountPercentage,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // تفعيل / إيقاف الكوبون
  Future<void> toggleCouponStatus(String id, bool currentStatus) async {
    await _firestore.collection('coupons').doc(id).update({'isActive': !currentStatus});
  }

  // مسح الكوبون نهائياً
  Future<void> deleteCoupon(String id) async {
    await _firestore.collection('coupons').doc(id).delete();
  }
}