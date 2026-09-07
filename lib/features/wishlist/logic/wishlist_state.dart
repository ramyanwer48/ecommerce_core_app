import '../../home/data/models/product_model.dart';

abstract class WishlistState {}

class WishlistInitial extends WishlistState {}

class WishlistUpdated extends WishlistState {
  final List<ProductModel> wishlistItems;
  WishlistUpdated(this.wishlistItems);
}