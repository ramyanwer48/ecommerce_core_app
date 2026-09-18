import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ecommerce_core_app/features/checkout/data/models/coupon_model.dart';
import '../data/repos/admin_coupons_repo.dart';


// ----- States -----
abstract class AdminCouponsState {}
class AdminCouponsInitial extends AdminCouponsState {}
class AdminCouponsLoading extends AdminCouponsState {}
class AdminCouponsLoaded extends AdminCouponsState {
  final List<CouponModel> coupons;
  AdminCouponsLoaded(this.coupons);
}
class AdminCouponsActionSuccess extends AdminCouponsState {
  final String message;
  AdminCouponsActionSuccess(this.message);
}
class AdminCouponsError extends AdminCouponsState {
  final String error;
  AdminCouponsError(this.error);
}

// ----- Cubit -----
class AdminCouponsCubit extends Cubit<AdminCouponsState> {
  final AdminCouponsRepo _repo;

  AdminCouponsCubit(this._repo) : super(AdminCouponsInitial());

  Future<void> fetchCoupons() async {
    emit(AdminCouponsLoading());
    try {
      final coupons = await _repo.getAllCoupons();
      emit(AdminCouponsLoaded(coupons));
    } catch (e) {
      emit(AdminCouponsError(e.toString()));
    }
  }

  Future<void> addCoupon(String code, double discount) async {
    try {
      await _repo.addCoupon(code: code, discountPercentage: discount);
      emit(AdminCouponsActionSuccess('تمت إضافة الكوبون بنجاح!'));
      await fetchCoupons();
    } catch (e) {
      emit(AdminCouponsError(e.toString()));
      await fetchCoupons();
    }
  }

  Future<void> toggleStatus(String id, bool currentStatus) async {
    try {
      await _repo.toggleCouponStatus(id, currentStatus);
      await fetchCoupons();
    } catch (e) {
      emit(AdminCouponsError(e.toString()));
    }
  }

  Future<void> deleteCoupon(String id) async {
    try {
      await _repo.deleteCoupon(id);
      emit(AdminCouponsActionSuccess('تم حذف الكوبون!'));
      await fetchCoupons();
    } catch (e) {
      emit(AdminCouponsError(e.toString()));
    }
  }
}