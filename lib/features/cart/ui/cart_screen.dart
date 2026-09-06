import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/cart_cubit.dart';
import '../logic/cart_state.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('سلة المشتريات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // نستخدم BlocBuilder للاستماع للتغييرات في السلة
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          // إذا لم يتم إضافة شيء بعد
          if (state is CartInitial || (state is CartUpdated && state.cartItems.isEmpty)) {
            return const Center(
              child: Text(
                'السلة فارغة حالياً 🛒',
                style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            );
          }

          // إذا كان هناك منتجات
          if (state is CartUpdated) {
            return Column(
              children: [
                // قائمة المنتجات في السلة
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = state.cartItems[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item.imageUrl.isNotEmpty
                                ? Image.network(item.imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                                : Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Icons.image)),
                          ),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('${item.price} ج.م', style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              // سنضيف لاحقاً دالة الحذف
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // شريط الإجمالي السفلي (Checkout Bar)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الإجمالي', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          Text(
                            '${state.totalPrice} ج.م',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF000826)),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4FF),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          // هنا سنبرمج إتمام الطلب لاحقاً
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('جاري إتمام الطلب...')),
                          );
                        },
                        child: const Text('إتمام الطلب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}