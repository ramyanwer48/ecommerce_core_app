import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/checkout_repo.dart';
import '../data/models/coupon_model.dart';
import '../../../core/networking/paymob_manager.dart';

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

// --- حالات بيموب (بطاقة) ---
class CheckoutPaymobLoading extends CheckoutState {}
class CheckoutPaymobSuccess extends CheckoutState {
  final String paymentKey;
  CheckoutPaymobSuccess(this.paymentKey);
}
class CheckoutPaymobError extends CheckoutState {
  final String error;
  CheckoutPaymobError(this.error);
}

// --- حالات بيموب (محفظة إلكترونية) ---
class CheckoutWalletLoading extends CheckoutState {}
class CheckoutWalletSuccess extends CheckoutState {
  final String redirectUrl;
  CheckoutWalletSuccess(this.redirectUrl);
}
class CheckoutWalletError extends CheckoutState {
  final String error;
  CheckoutWalletError(this.error);
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

  // 4. دالة جلب مفتاح الدفع من بيموب (بطاقة)
  Future<void> getPaymobPaymentKey({required double totalAmount}) async {
    emit(CheckoutPaymobLoading());
    try {
      Map<String, dynamic> billingData = {
        "first_name": "Ramy",
        "last_name": "Hafez",
        "email": "test@test.com",
        "phone_number": "01000000000",
        "apartment": "NA",
        "floor": "NA",
        "street": "NA",
        "building": "NA",
        "shipping_method": "NA",
        "postal_code": "NA",
        "city": "Cairo",
        "country": "EG",
        "state": "NA"
      };

      String paymentKey = await PaymobManager.getPaymentKey(
        amount: totalAmount,
        billingData: billingData,
      );

      emit(CheckoutPaymobSuccess(paymentKey));
    } catch (e) {
      emit(CheckoutPaymobError(e.toString()));
    }
  }

  // 5. دالة الدفع بالمحفظة الإلكترونية
  Future<void> payWithWallet({
    required double totalAmount,
    required String walletPhoneNumber,
  }) async {
    emit(CheckoutWalletLoading());
    try {
      Map<String, dynamic> billingData = {
        "first_name": "Ramy",
        "last_name": "Hafez",
        "email": "test@test.com",
        "phone_number": walletPhoneNumber,
        "apartment": "NA",
        "floor": "NA",
        "street": "NA",
        "building": "NA",
        "shipping_method": "NA",
        "postal_code": "NA",
        "city": "Cairo",
        "country": "EG",
        "state": "NA"
      };

      String redirectUrl = await PaymobManager.payWithWallet(
        amount: totalAmount,
        walletPhoneNumber: walletPhoneNumber,
        billingData: billingData,
      );

      emit(CheckoutWalletSuccess(redirectUrl));
    } catch (e) {
      emit(CheckoutWalletError(e.toString()));
    }
  }
}