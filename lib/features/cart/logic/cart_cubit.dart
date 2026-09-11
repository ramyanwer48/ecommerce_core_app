import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../home/data/models/product_model.dart';
import 'cart_state.dart';

// 👈 كلاس صغير لربط المنتج بكميته المطلوبة في السلة
class CartItemModel {
  final ProductModel product;
  int quantity;

  CartItemModel({required this.product, this.quantity = 1});
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(CartInitial());

  // 👈 تحويل الليستة لتعتمد على الموديل الجديد
  final List<CartItemModel> _items = [];

  // 1. إضافة منتج للسلة (أو زيادة كميته لو موجود)
  void addToCart(ProductModel product) {
    // التحقق هل المنتج موجود بالفعل؟
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      // لو موجود، زود الكمية
      _items[existingIndex].quantity++;
    } else {
      // لو جديد، ضيفه كعنصر جديد
      _items.add(CartItemModel(product: product));
    }
    _calculateTotal();
  }

  // 2. زيادة كمية المنتج من داخل السلة (+)
  void increaseQuantity(ProductModel product) {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      // 🛡️ حارس المخزون الافتراضي (يمكنك تعديل الرقم لو عندك حقل للمخزون)
      if (_items[existingIndex].quantity < 10) {
        _items[existingIndex].quantity++;
        _calculateTotal();
      } else {
        emit(CartError("وصلت للحد الأقصى للكمية المتاحة"));
        _calculateTotal(); // للرجوع للحالة الصحيحة وعرض البيانات
      }
    }
  }

  // 3. تقليل كمية المنتج من داخل السلة (-)
  void decreaseQuantity(ProductModel product) {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity > 1) {
        // تقليل الكمية
        _items[existingIndex].quantity--;
      } else {
        // لو الكمية 1 ونقصها، نحذفه من السلة خالص
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

  // 5. حساب الإجمالي بدقة (السعر × الكمية)
  void _calculateTotal() {
    double total = _items.fold(0, (sum, item) => sum + (item.product.price * item.quantity));

    // استخراج قائمة المنتجات العادية لإرسالها للـ State عشان متبوظش الـ UI القديم عندك
    final List<ProductModel> rawProducts = _items.map((e) => e.product).toList();

    emit(CartUpdated(List.from(rawProducts), total));
  }

  // للحصول على كمية منتج معين (لشاشة السلة)
  int getQuantity(ProductModel product) {
    final item = _items.firstWhere(
          (e) => e.product.id == product.id,
      orElse: () => CartItemModel(product: product, quantity: 0),
    );
    return item.quantity;
  }

  // 6. إتمام الطلب وإرساله إلى Firebase
  // 6. إتمام الطلب وإرساله إلى Firebase
  Future<void> checkout({
    required String address,
    required String phone,
    required double finalTotal, // 👈 الإجمالي بعد الخصم
    required String paymentMethod, // 👈 طريقة الدفع
  }) async {
    if (_items.isEmpty) return;

    try {
      emit(CartLoading());

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("حدث خطأ: المستخدم غير مسجل الدخول");

      // 🚀 إحضار رقم الطلب التسلسلي
      final counterRef = FirebaseFirestore.instance.collection('system').doc('counters');
      final counterDoc = await counterRef.get();
      int newOrderNumber = 1;

      if (counterDoc.exists) {
        newOrderNumber = (counterDoc.data()?['lastOrderNumber'] ?? 0) + 1;
        await counterRef.update({'lastOrderNumber': newOrderNumber});
      } else {
        await counterRef.set({'lastOrderNumber': 1});
      }

      final orderData = {
        'orderNumber': newOrderNumber,
        'userId': user.uid,
        'userEmail': user.email ?? 'غير معروف',
        'address': address,
        'phone': phone,
        'totalPrice': finalTotal, // 👈 حفظنا الإجمالي النهائي
        'paymentMethod': paymentMethod, // 👈 حفظنا طريقة الدفع في الفاتورة
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

      await FirebaseFirestore.instance.collection('orders').add(orderData);

      _items.clear(); // تفريغ السلة
      emit(CartCheckoutSuccess());
      emit(CartUpdated([], 0));
    } catch (e) {
      emit(CartError(e.toString()));
      _calculateTotal();
    }
  }
}