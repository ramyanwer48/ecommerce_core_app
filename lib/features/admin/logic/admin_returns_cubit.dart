import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/admin_returns_repo.dart';
import 'admin_returns_state.dart';

class AdminReturnsCubit extends Cubit<AdminReturnsState> {
  final AdminReturnsRepo _repo;
  List _pendingReturns = [];

  AdminReturnsCubit(this._repo) : super(AdminReturnsInitial());

  Future<void> fetchPendingReturns() async {
    emit(AdminReturnsLoading());
    try {
      final result = await _repo.getPendingReturns();
      _pendingReturns = result as List;
      emit(AdminReturnsLoaded(_pendingReturns));
    } catch (e) {
      emit(AdminReturnsError(e.toString()));
    }
  }

  Future<void> approveRequest(String returnId, Map returnData) async {
    emit(AdminReturnsActionLoading());
    try {
      await _repo.approveReturn(returnId, returnData);

      // إزالة الطلب من القائمة محلياً بعد الاعتماد لتحديث الشاشة فوراً
      _pendingReturns.removeWhere((element) {
        Map el = element as Map;
        return el['id'] == returnId;
      });

      emit(AdminReturnsActionSuccess('تم اعتماد المرتجع، وخصم القيمة من الخزينة، وإرجاع المنتجات للمخزن بنجاح.'));
      emit(AdminReturnsLoaded(_pendingReturns));
    } catch (e) {
      emit(AdminReturnsError(e.toString()));
      emit(AdminReturnsLoaded(_pendingReturns));
    }
  }

  Future<void> rejectRequest(String returnId, String orderId) async {
    emit(AdminReturnsActionLoading());
    try {
      await _repo.rejectReturn(returnId, orderId);

      // إزالة الطلب من القائمة محلياً بعد الرفض
      _pendingReturns.removeWhere((element) {
        Map el = element as Map;
        return el['id'] == returnId;
      });

      emit(AdminReturnsActionSuccess('تم رفض طلب المرتجع.'));
      emit(AdminReturnsLoaded(_pendingReturns));
    } catch (e) {
      emit(AdminReturnsError(e.toString()));
      emit(AdminReturnsLoaded(_pendingReturns));
    }
  }
}