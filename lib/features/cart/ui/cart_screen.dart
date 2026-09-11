import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';
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
      body: BlocConsumer<CartCubit, CartState>(
        listener: (context, state) {
          // سيتم نقل منطق نجاح الطلب لاحقاً إلى CheckoutCubit
          if (state is CartError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<CartCubit>();

          if (state is CartLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)));
          }

          if (state is CartInitial || (state is CartUpdated && state.cartItems.isEmpty)) {
            return const Center(
              child: Text('السلة فارغة حالياً 🛒', style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
            );
          }

          if (state is CartUpdated) {
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = state.cartItems[index];
                      final quantity = cubit.getQuantity(item);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item.imageUrl.isNotEmpty
                                    ? Image.network(item.imageUrl, width: 70, height: 70, fit: BoxFit.cover)
                                    : Container(width: 70, height: 70, color: Colors.grey[200], child: const Icon(Icons.image)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text('${item.price} ج.م', style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () => cubit.decreaseQuantity(item),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                          child: const Icon(Icons.remove, size: 18, color: Colors.black),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text('$quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 12),
                                      InkWell(
                                        onTap: () => cubit.increaseQuantity(item),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(color: const Color(0xFF00D4FF), borderRadius: BorderRadius.circular(6)),
                                          child: const Icon(Icons.add, size: 18, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () => cubit.removeFromCart(item),
                                    child: const Text('حذف', style: TextStyle(color: Colors.red, fontSize: 12)),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الإجمالي', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          Text('${state.totalPrice} ج.م', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF000826))),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4FF),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          // 👇 هنا السحر: هننتقل لشاشة الدفع ونبعت الإجمالي الحقيقي للسلة كـ Extra
                          context.push('/checkout', extra: state.totalPrice);
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