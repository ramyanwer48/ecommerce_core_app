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
  Future<void> checkout() async {
    if (_items.isEmpty) return;

    try {
      final currentTotal = _items.fold(0.0, (sum, item) => sum + item.price);
      emit(CartLoading()); // عرض دائرة التحميل

      // جلب بيانات المستخدم الحالي
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("حدث خطأ: المستخدم غير مسجل الدخول");

      // تجهيز الفاتورة (الطلب)
      final orderData = {
        'userId': user.uid,
        'userEmail': user.email,
        'totalPrice': currentTotal,
        'orderDate': FieldValue.serverTimestamp(), // توقيت سيرفر جوجل
        'status': 'Pending', // قيد المراجعة
        'items': _items.map((item) => {
          'name': item.name,
          'price': item.price,
        }).toList(),
      };

      // رفع الطلب إلى مجموعة 'orders' في Firestore
      await FirebaseFirestore.instance.collection('orders').add(orderData);

      // تنظيف السلة بعد نجاح الطلب
      _items.clear();
      emit(CartCheckoutSuccess());
      emit(CartUpdated([], 0)); // العودة لشاشة سلة فارغة

    } catch (e) {
      emit(CartError(e.toString()));
      _calculateTotal(); // العودة لحالة السلة في حال فشل الطلب
    }
  }
}