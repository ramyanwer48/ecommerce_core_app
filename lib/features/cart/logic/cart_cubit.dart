import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/data/models/product_model.dart';
import 'cart_state.dart';

// كلاس لربط المنتج بكميته المطلوبة في السلة
class CartItemModel {
  final ProductModel product;
  int quantity;

  CartItemModel({required this.product, this.quantity = 1});
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(CartInitial());

  final List<CartItemModel> _items = [];

  // 👇 إضافة Getter لتحويل بيانات السلة لـ JSON لإرسالها للسيرفر أو لـ CheckoutRepo
  List<Map<String, dynamic>> get cartItemsAsMap {
    return _items.map((item) => {
      'productId': item.product.id,
      'name': item.product.name,
      'price': item.product.price,
      'quantity': item.quantity,
      'imageUrl': item.product.imageUrl,
    }).toList();
  }

  // 1. إضافة منتج للسلة مع فحص المخزون المتاح
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

  // 2. زيادة كمية المنتج
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

  // 3. تقليل كمية المنتج
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

  // 4. حذف منتج من السلة نهائياً
  void removeFromCart(ProductModel product) {
    _items.removeWhere((item) => item.product.id == product.id);
    _calculateTotal();
  }

  // 5. حساب الإجمالي بدقة
  void _calculateTotal() {
    double total = _items.fold(0, (totalSum, item) => totalSum + (item.product.price * item.quantity));
    int totalQuantity = _items.fold(0, (sum, item) => sum + item.quantity);

    final List<ProductModel> rawProducts = _items.map((e) => e.product).toList();
    emit(CartUpdated(List.from(rawProducts), total, totalQuantity));
  }

  // الحصول على كمية منتج معين
  int getQuantity(ProductModel product) {
    final item = _items.firstWhere(
          (e) => e.product.id == product.id,
      orElse: () => CartItemModel(product: product, quantity: 0),
    );
    return item.quantity;
  }

  // 🌟 تفريغ السلة بالكامل بعد نجاح الطلب 🌟
  // (سيتم استدعاؤها من الـ CheckoutCubit بعد نجاح حفظ الأوردر في فايربيز)
  void clearCart() {
    _items.clear();
    emit(CartUpdated([], 0, 0));
  }
}