import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../home/data/models/product_model.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(CartInitial());

  final List<ProductModel> _items = [];

  // 1. إضافة منتج
  void addToCart(ProductModel product) {
    _items.add(product);
    _calculateTotal();
  }

  // 2. حذف منتج من السلة
  void removeFromCart(ProductModel product) {
    _items.remove(product);
    _calculateTotal();
  }

  // 3. حساب الإجمالي
  void _calculateTotal() {
    double total = _items.fold(0, (sum, item) => sum + item.price);
    emit(CartUpdated(List.from(_items), total));
  }

  // 4. إتمام الطلب وإرساله إلى Firebase
  Future<void> checkout({required String address, required String phone}) async {
    if (_items.isEmpty) return;

    try {
      final currentTotal = _items.fold(0.0, (sum, item) => sum + item.price);
      emit(CartLoading());

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("حدث خطأ: المستخدم غير مسجل الدخول");

      final orderData = {
        'userId': user.uid,
        'userEmail': user.email ?? 'غير معروف', // حماية إضافية هنا
        'address': address, // تم إضافة العنوان
        'phone': phone,     // تم إضافة الهاتف
        'totalPrice': currentTotal,
        'orderDate': FieldValue.serverTimestamp(),
        'status': 'Pending',
        'items': _items.map((item) => {
          'name': item.name,
          'price': item.price,
        }).toList(),
      };

      await FirebaseFirestore.instance.collection('orders').add(orderData);

      _items.clear();
      emit(CartCheckoutSuccess());
      emit(CartUpdated([], 0));
    } catch (e) {
      emit(CartError(e.toString()));
      _calculateTotal();
    }
  }
}