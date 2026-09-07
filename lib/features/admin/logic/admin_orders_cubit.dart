import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/admin_orders_repo.dart';
import 'admin_orders_state.dart';

class AdminOrdersCubit extends Cubit<AdminOrdersState> {
  final AdminOrdersRepo _repo;

  AdminOrdersCubit(this._repo) : super(AdminOrdersInitial());

  Future<void> fetchAllOrders() async {
    emit(AdminOrdersLoading());
    try {
      final orders = await _repo.getAllOrders();
      emit(AdminOrdersLoaded(orders));
    } catch (e) {
      emit(AdminOrdersError(e.toString()));
    }
  }

  Future<void> updateStatus(String orderId, String newStatus) async {
    try {
      await _repo.updateOrderStatus(orderId, newStatus);
      emit(AdminOrderStatusUpdated());
      fetchAllOrders(); // إعادة تحميل قائمة الطلبات بعد التحديث
    } catch (e) {
      emit(AdminOrdersError(e.toString()));
    }
  }
}