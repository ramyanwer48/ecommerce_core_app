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
  final double discountAmount;
  final double finalTotal;
  CheckoutCouponApplied(this.coupon, this.discountAmount, this.finalTotal);
}
class CheckoutCouponError extends CheckoutState {
  final String error;
  CheckoutCouponError(this.error);
}

class CheckoutPaymobLoading extends CheckoutState {}
class CheckoutPaymobSuccess extends CheckoutState {
  final String paymentKey;
  CheckoutPaymobSuccess(this.paymentKey);
}
class CheckoutPaymobError extends CheckoutState {
  final String error;
  CheckoutPaymobError(this.error);
}

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

  double subTotal = 0.0;
  CouponModel? appliedCoupon;

  CheckoutCubit(this._repo) : super(CheckoutInitial());

  void initCheckout(double cartTotal) {
    subTotal = cartTotal;
    emit(CheckoutInitial());
  }

  Future<void> applyCoupon(String code) async {
    emit(CheckoutCouponLoading());
    try {
      final coupon = await _repo.validateCoupon(code.trim());

      if (coupon != null) {
        appliedCoupon = coupon;
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

  void removeCoupon() {
    appliedCoupon = null;
    emit(CheckoutInitial());
  }

  // 4. الدفع الآمن عبر Cloud Functions (تم التحديث)
  Future<void> getPaymobPaymentKey({
    required double totalAmount,
    required String phone,
    required String address,
    required List<Map<String, dynamic>> items,
  }) async {
    emit(CheckoutPaymobLoading());
    try {
      Map<String, dynamic> billingData = {
        "first_name": "Client", // يمكن استبدالها ببيانات المستخدم الحقيقية لاحقاً
        "last_name": "Name",
        "email": "test@test.com",
        "phone_number": phone,
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

      // الاتصال بالدالة الآمنة في PaymobManager
      String paymentKey = await PaymobManager.getPaymentKey(
        amount: totalAmount,
        billingData: billingData,
        phone: phone,
        address: address,
        items: items,
      );

      emit(CheckoutPaymobSuccess(paymentKey));
    } catch (e) {
      emit(CheckoutPaymobError(e.toString()));
    }
  }

  // 5. الدفع بالمحفظة الإلكترونية (معلق مؤقتاً لحين ربطه بالسيرفر)
  Future<void> payWithWallet({
    required double totalAmount,
    required String walletPhoneNumber,
  }) async {
    emit(CheckoutWalletLoading());
    try {
      // TODO: سيتم إنشاء Cloud Function خاصة بالمحافظ الإلكترونية قريباً
      throw Exception('خدمة المحافظ الإلكترونية قيد التحديث لرفع مستوى الأمان.');
    } catch (e) {
      emit(CheckoutWalletError(e.toString()));
    }
  }
}