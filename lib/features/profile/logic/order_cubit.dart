import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/order_repo.dart';
import 'order_state.dart';

class OrderCubit extends Cubit<OrderState> {
  final OrderRepo _orderRepo;

  OrderCubit(this._orderRepo) : super(OrderInitial());

  Future<void> fetchOrders() async {
    emit(OrderLoading());
    try {
      final orders = await _orderRepo.getUserOrders();
      emit(OrderLoaded(orders));
    } catch (e) {
      emit(OrderError(e.toString()));
    }
  }

  // 👈 الدالة الجديدة لإلغاء الطلب من طرف العميل
  Future<void> cancelOrder(String orderId) async {
    try {
      // إظهار حالة التحميل أثناء الإلغاء
      emit(OrderLoading());
      await _orderRepo.cancelOrder(orderId);
      // بعد نجاح الإلغاء في فايربيز، نقوم بجلب الطلبات مجدداً لتحديث الواجهة
      await fetchOrders();
    } catch (e) {
      emit(OrderError(e.toString()));
    }
  }
}