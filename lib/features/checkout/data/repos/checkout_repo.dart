import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/coupon_model.dart';

class CheckoutRepo {
  final _firestore = FirebaseFirestore.instance;

  // 🔍 دالة التحقق من الكوبون السحرية
  Future<CouponModel?> validateCoupon(String code) async {
    final snapshot = await _firestore
        .collection('coupons')
        .where('code', isEqualTo: code)
        .where('isActive', isEqualTo: true) // يتأكد إنك كأدمن مش موقفه
        .get();

    if (snapshot.docs.isNotEmpty) {
      // الكوبون سليم 100%
      return CouponModel.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);
    }
    // الكوبون غير صحيح أو متوقف
    return null;
  }
}