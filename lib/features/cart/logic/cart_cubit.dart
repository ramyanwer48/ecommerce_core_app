import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/data/models/product_model.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(CartInitial());

  // القائمة التي ستحتفظ بالمنتجات
  final List<ProductModel> _items = [];

  void addToCart(ProductModel product) {
    _items.add(product);
    _calculateTotal();
  }

  void _calculateTotal() {
    // حساب الإجمالي برمجياً
    double total = _items.fold(0, (sum, item) => sum + item.price);
    emit(CartUpdated(List.from(_items), total)); // تحديث حالة السلة
  }
}