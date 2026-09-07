import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/data/models/product_model.dart';
import 'wishlist_state.dart';

class WishlistCubit extends Cubit<WishlistState> {
  WishlistCubit() : super(WishlistInitial());

  final List<ProductModel> _items = [];

  // إضافة أو حذف المنتج بضغطة واحدة
  void toggleWishlist(ProductModel product) {
    if (_items.any((item) => item.id == product.id)) {
      _items.removeWhere((item) => item.id == product.id);
    } else {
      _items.add(product);
    }
    emit(WishlistUpdated(List.from(_items)));
  }

  // فحص هل المنتج موجود في المفضلة لإنارة القلب باللون الأحمر
  bool isInWishlist(String productId) {
    return _items.any((item) => item.id == productId);
  }
}