import '../data/models/product_model.dart'; // مسار الاستدعاء الصحيح

abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<ProductModel> products;
  HomeLoaded(this.products);
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
}