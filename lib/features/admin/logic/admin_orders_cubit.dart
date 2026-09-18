import 'package:flutter_bloc/flutter_bloc.dart';
import '../../admin/data/repos/admin_repo.dart'; // 👈 ضبط المسار الصحيح حسب مكان ملف admin_repo عندك
import '../data/repos/admin_orders_repo.dart';
import 'admin_orders_state.dart';

class AdminOrdersCubit extends Cubit<AdminOrdersState> {
  final AdminOrdersRepo _ordersRepo;
  final AdminRepo _adminRepo;

  AdminOrdersCubit(this._ordersRepo, this._adminRepo) : super(AdminOrdersInitial());

  Future<void> fetchAllOrders() async {
    emit(AdminOrdersLoading());
    try {
      final orders = await _ordersRepo.getAllOrders();
      emit(AdminOrdersLoaded(orders));
    } catch (e) {
      emit(AdminOrdersError(e.toString()));
    }
  }

  Future<void> updateStatus(String orderId, String userId, String newStatus) async {
    try {
      if (newStatus.toLowerCase() == 'cancelled') {
        await _adminRepo.updateOrderStatusAndRestoreStock(
          orderId: orderId,
          newStatus: newStatus,
        );
      } else {
        await _ordersRepo.updateOrderStatus(orderId, newStatus);
      }

      emit(AdminOrderStatusUpdated());
      fetchAllOrders();
    } catch (e) {
      emit(AdminOrdersError(e.toString()));
    }
  }
}