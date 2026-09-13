import '../../home/data/models/product_model.dart';

abstract class CartState {}

class CartInitial extends CartState {}

class CartUpdated extends CartState {
  final List<ProductModel> cartItems;
  final double totalPrice;
  final int totalQuantity; // 👈 عدد القطع الكلي للـ Badge

  CartUpdated(this.cartItems, this.totalPrice, this.totalQuantity);
}

// حالات التحكم في عملية الشراء
class CartLoading extends CartState {}

class CartCheckoutSuccess extends CartState {}

class CartError extends CartState {
  final String error;
  CartError(this.error);
}