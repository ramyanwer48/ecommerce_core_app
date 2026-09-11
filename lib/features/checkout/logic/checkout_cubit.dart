import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/checkout_repo.dart';
import '../data/models/coupon_model.dart';

// --- الحالات (States) ---
abstract class CheckoutState {}
class CheckoutInitial extends CheckoutState {}
class CheckoutCouponLoading extends CheckoutState {}
class CheckoutCouponApplied extends CheckoutState {
  final CouponModel coupon;
  final double discountAmount; // قيمة الخصم بالفلوس
  final double finalTotal; // الإجمالي بعد الخصم
  CheckoutCouponApplied(this.coupon, this.discountAmount, this.finalTotal);
}
class CheckoutCouponError extends CheckoutState {
  final String error;
  CheckoutCouponError(this.error);
}

// --- المحرك (Cubit) ---
class CheckoutCubit extends Cubit<CheckoutState> {
  final CheckoutRepo _repo;

  double subTotal = 0.0; // إجمالي السلة قبل الخصم
  CouponModel? appliedCoupon; // الكوبون المستخدم حالياً

  CheckoutCubit(this._repo) : super(CheckoutInitial());

  // 1. تمرير إجمالي السلة للكيوبيت عند فتح شاشة الدفع
  void initCheckout(double cartTotal) {
    subTotal = cartTotal;
    emit(CheckoutInitial());
  }

  // 2. تطبيق الكوبون وحساب الحسبة الرياضية
  Future<void> applyCoupon(String code) async {
    emit(CheckoutCouponLoading());
    try {
      final coupon = await _repo.validateCoupon(code.trim());

      if (coupon != null) {
        appliedCoupon = coupon;

        // العملية الحسابية للخصم
        double discountAmount = (subTotal * coupon.discountPercentage) / 100;
        double finalTotal = subTotal - discountAmount;

        emit(CheckoutCouponApplied(coupon, discountAmount, finalTotal));
      } else {
        emit(CheckoutCouponError('الكوبون غير صحيح أو منتهي الصلاحية ❌'));
      }
    } catch (e) {
      emit(CheckoutCouponError('حدث خطأ أثناء الاتصال بالخادم'));
    }
  }

  // 3. إلغاء الكوبون لو العميل غير رأيه
  void removeCoupon() {
    appliedCoupon = null;
    emit(CheckoutInitial());
  }
}