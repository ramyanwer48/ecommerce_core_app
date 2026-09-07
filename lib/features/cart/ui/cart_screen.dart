import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';
import '../logic/cart_cubit.dart';
import '../logic/cart_state.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  // النافذة المنبثقة لطلب بيانات التوصيل
  void _showCheckoutForm(BuildContext context, CartCubit cubit) {
    final formKey = GlobalKey<FormState>();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // مهم جداً لرفع النافذة فوق الكيبورد
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24, left: 24, right: 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('بيانات التوصيل 🚚', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF000826))),
                const SizedBox(height: 20),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: const Icon(Icons.phone, color: Color(0xFF00D4FF)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'برجاء إدخال رقم الهاتف' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: 'عنوان التوصيل بالتفصيل',
                    prefixIcon: const Icon(Icons.location_on, color: Color(0xFF00D4FF)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'برجاء إدخال العنوان' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(context); // إغلاق النافذة المنبثقة
                        // إرسال الطلب لفايربيز بالبيانات الجديدة
                        cubit.checkout(address: addressController.text, phone: phoneController.text);
                      }
                    },
                    child: const Text('تأكيد الطلب', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

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
          if (state is CartCheckoutSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إرسال طلبك بنجاح! 🚀', style: TextStyle(fontSize: 16)),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.push(Routes.orders);
          } else if (state is CartError) {
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
                              cubit.removeFromCart(item);
                            },
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
                          // استدعاء النافذة المنبثقة بدلاً من الدفع المباشر
                          _showCheckoutForm(context, cubit);
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