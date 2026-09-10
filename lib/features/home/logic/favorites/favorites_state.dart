// lib/features/home/logic/favorites/favorites_state.dart
import '../../data/models/favorite_model.dart';

abstract class FavoritesState {}

class FavoritesInitial extends FavoritesState {}

class FavoritesLoading extends FavoritesState {}

class FavoritesLoaded extends FavoritesState {
  final List<FavoriteModel> favoriteProducts;
  // نمرر قائمة بمعرفات المنتجات لتسهيل فحص إذا كان المنتج مفضلاً أم لا في واجهة المستخدم
  final List<String> favoriteIds;

  FavoritesLoaded(this.favoriteProducts, this.favoriteIds);
}

class FavoritesError extends FavoritesState {
  final String error;
  FavoritesError(this.error);
}