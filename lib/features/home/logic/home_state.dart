import '../data/models/product_model.dart';
import '../data/models/category_model.dart'; // 👈 استدعاء الموديل الجديد

abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<ProductModel> products;
  final List<CategoryModel> categories; // 👈 إضافة الأقسام للـ State

  HomeLoaded(this.products, this.categories);
}

class HomeError extends HomeState {
  final String error;
  HomeError(this.error);
}