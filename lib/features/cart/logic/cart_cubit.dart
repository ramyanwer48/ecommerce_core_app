import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // 1. إضافة منتج للسلة مع فحص المخزون المتاح
  void addToCart(ProductModel product) {
    final availableStock = product.stockQuantity;

    // التأكد من توفر المنتج بالمستودع
    if (availableStock <= 0) {
      emit(CartError("عذراً، هذا المنتج غير متوفر في المخزن حالياً"));
      _calculateTotal();
      return;
    }

    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      // التحقق من عدم تخطي الكمية المخزنية
      if (_items[existingIndex].quantity < availableStock) {
        _items[existingIndex].quantity++;
      } else {
        emit(CartError("لا يمكنك إضافة المزيد، الكمية المتوفرة في المخزن هي $availableStock قطع فقط"));
      }
    } else {
      _items.add(CartItemModel(product: product));
    }
    _calculateTotal();
  }

  // 2. زيادة كمية المنتج من داخل السلة (+) مقيدة بالمخزون الفعلي
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

  // 3. تقليل كمية المنتج من داخل السلة (-)
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

  // 5. حساب الإجمالي بدقة وإجمالي عدد القطع
  void _calculateTotal() {
    double total = _items.fold(0, (totalSum, item) => totalSum + (item.product.price * item.quantity));
    int totalQuantity = _items.fold(0, (sum, item) => sum + item.quantity);

    final List<ProductModel> rawProducts = _items.map((e) => e.product).toList();
    emit(CartUpdated(List.from(rawProducts), total, totalQuantity));
  }

  // الحصول على كمية منتج معين داخل السلة
  int getQuantity(ProductModel product) {
    final item = _items.firstWhere(
          (e) => e.product.id == product.id,
      orElse: () => CartItemModel(product: product, quantity: 0),
    );
    return item.quantity;
  }

  // 6. إتمام الطلب والخصم الآمن من المخزون بواسطة Transaction
  Future<void> checkout({
    required String address,
    required String phone,
    required double finalTotal,
    required String paymentMethod,
  }) async {
    if (_items.isEmpty) return;

    try {
      emit(CartLoading());

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("حدث خطأ: المستخدم غير مسجل الدخول");

      final firestore = FirebaseFirestore.instance;
      final counterRef = firestore.collection('system').doc('counters');

      // 🛡️ تنفيذ العملية عبر Transaction لضمان الذرية (Atomic) ومطابقة المخزون
      await firestore.runTransaction((transaction) async {
        // أ. قراءة العداد التسلسلي
        final counterDoc = await transaction.get(counterRef);
        int newOrderNumber = 1;
        if (counterDoc.exists) {
          newOrderNumber = (counterDoc.data()?['lastOrderNumber'] ?? 0) + 1;
        }

        // ب. قراءة المخزون الفعلي للمنتجات في السلة للتحقق قبل الخصم
        for (final item in _items) {
          final productRef = firestore.collection('products').doc(item.product.id);
          final productDoc = await transaction.get(productRef);

          if (!productDoc.exists) {
            throw Exception("المنتج ${item.product.name} لم يعد متاحاً!");
          }

          final currentStock = (productDoc.data()?['stockQuantity'] as num?)?.toInt() ?? 0;
          if (currentStock < item.quantity) {
            throw Exception("عذراً، نفد مخزون: ${item.product.name} (المتبقي: $currentStock فقط)");
          }
        }

        // ج. تحديث العداد
        transaction.set(
          counterRef,
          {'lastOrderNumber': newOrderNumber},
          SetOptions(merge: true),
        );

        // د. إنشاء الفاتورة داخل مجموعة orders
        final newOrderRef = firestore.collection('orders').doc();
        final orderData = {
          'orderNumber': newOrderNumber,
          'userId': user.uid,
          'userEmail': user.email ?? 'غير معروف',
          'address': address,
          'phone': phone,
          'totalPrice': finalTotal,
          'paymentMethod': paymentMethod,
          'orderDate': FieldValue.serverTimestamp(),
          'status': 'Pending',
          'items': _items.map((item) => {
            'productId': item.product.id,
            'name': item.product.name,
            'price': item.product.price,
            'quantity': item.quantity,
            'imageUrl': item.product.imageUrl,
          }).toList(),
        };
        transaction.set(newOrderRef, orderData);

        // هـ. خصم الكميات المباعة من المستودع مباشرة
        for (final item in _items) {
          final productRef = firestore.collection('products').doc(item.product.id);
          transaction.update(productRef, {
            'stockQuantity': FieldValue.increment(-item.quantity),
          });
        }
      });

      _items.clear();
      emit(CartCheckoutSuccess());
      emit(CartUpdated([], 0, 0));
    } catch (e) {
      emit(CartError(e.toString().replaceAll("Exception: ", "")));
      _calculateTotal();
    }
  }
}