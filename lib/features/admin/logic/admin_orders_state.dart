import '../../profile/data/models/order_model.dart';

abstract class AdminOrdersState {}

class AdminOrdersInitial extends AdminOrdersState {}
class AdminOrdersLoading extends AdminOrdersState {}
class AdminOrdersLoaded extends AdminOrdersState {
  final List<OrderModel> orders;
  AdminOrdersLoaded(this.orders);
}
class AdminOrdersError extends AdminOrdersState {
  final String error;
  AdminOrdersError(this.error);
}
class AdminOrderStatusUpdated extends AdminOrdersState {}