import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/data/models/product_model.dart';
import 'cart_state.dart';

class CartItemModel {
  final ProductModel product;
  int quantity;

  CartItemModel({required this.product, this.quantity = 1});
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(CartInitial());

  final List<CartItemModel> _items = [];

  List<Map<String, dynamic>> get cartItemsAsMap {
    return _items.map((item) {
      // 👈 تأمين قراءة الصورة لتفادي أي Crash بسبب تعدد الصور
      String finalImage = '';
      if (item.product.images != null && item.product.images!.isNotEmpty) {
        finalImage = item.product.images!.first;
      } else {
        finalImage = item.product.imageUrl;
      }

      return {
        'productId': item.product.id,
        'name': item.product.name,
        'price': item.product.price,
        'quantity': item.quantity,
        'imageUrl': finalImage,
      };
    }).toList();
  }

  void addToCart(ProductModel product) {
    final availableStock = product.stockQuantity;

    if (availableStock <= 0) {
      emit(CartError("عذراً، هذا المنتج غير متوفر في المخزن حالياً"));
      _calculateTotal();
      return;
    }

    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity < availableStock) {
        _items[existingIndex].quantity++;
      } else {
        emit(CartError("لا يمكنك إضافة المزيد، الكمية المتوفرة هي $availableStock قطع فقط"));
      }
    } else {
      _items.add(CartItemModel(product: product));
    }
    _calculateTotal();
  }

  void increaseQuantity(ProductModel product) {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      final availableStock = product.stockQuantity;

      if (_items[existingIndex].quantity < availableStock) {
        _items[existingIndex].quantity++;
        _calculateTotal();
      } else {
        emit(CartError("عذراً، أقصى كمية متوفرة في المخزن هي $availableStock فقط"));
        _calculateTotal();
      }
    }
  }

  void decreaseQuantity(ProductModel product) {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity > 1) {
        _items[existingIndex].quantity--;
      } else {
        _items.removeAt(existingIndex);
      }
      _calculateTotal();
    }
  }

  void removeFromCart(ProductModel product) {
    _items.removeWhere((item) => item.product.id == product.id);
    _calculateTotal();
  }

  void _calculateTotal() {
    double total = _items.fold(0, (totalSum, item) => totalSum + (item.product.price * item.quantity));
    int totalQuantity = _items.fold(0, (sum, item) => sum + item.quantity);

    final List<ProductModel> rawProducts = _items.map((e) => e.product).toList();
    emit(CartUpdated(List.from(rawProducts), total, totalQuantity));
  }

  int getQuantity(ProductModel product) {
    final item = _items.firstWhere(
          (e) => e.product.id == product.id,
      orElse: () => CartItemModel(product: product, quantity: 0),
    );
    return item.quantity;
  }

  void clearCart() {
    _items.clear();
    emit(CartUpdated([], 0, 0));
  }
}