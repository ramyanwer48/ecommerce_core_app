import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';
import '../../../core/di/dependency_injection.dart'; // عشان نقرأ الـ CartCubit
import '../../cart/logic/cart_cubit.dart';
import '../../cart/logic/cart_state.dart';
import '../logic/checkout_cubit.dart';

class CheckoutScreen extends StatefulWidget {
  final double cartTotal;

  const CheckoutScreen({super.key, required this.cartTotal});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String _selectedPaymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    context.read<CheckoutCubit>().initCheckout(widget.cartTotal);
  }

  @override
  void dispose() {
    _couponController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('إتمام الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
      ),
      // 👇 بنستمع للـ CartCubit عشان نعرف امتى الطلب اتسجل بنجاح
      body: BlocListener<CartCubit, CartState>(
        bloc: getIt<CartCubit>(), // استدعاء الكيوبيت العام بتاع السلة
        listener: (context, state) {
          if (state is CartCheckoutSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تسجيل الطلب بنجاح! 🚀'), backgroundColor: Colors.green),
            );
            context.pushReplacement(Routes.orders); // نقل العميل لشاشة طلباتي
          } else if (state is CartError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        child: BlocConsumer<CheckoutCubit, CheckoutState>(
          listener: (context, state) {
            if (state is CheckoutCouponApplied) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تفعيل الكوبون! 🎉'), backgroundColor: Colors.green),
              );
            } else if (state is CheckoutCouponError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error), backgroundColor: Colors.red),
              );
            }
          },
          builder: (context, state) {
            final cubit = context.read<CheckoutCubit>();

            double displayTotal = cubit.subTotal;
            double discount = 0.0;

            if (state is CheckoutCouponApplied) {
              displayTotal = state.finalTotal;
              discount = state.discountAmount;
            }

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. ملخص الطلب
                  _buildSectionTitle('ملخص الطلب 🧾'),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المجموع الفرعي:'),
                              Text('${cubit.subTotal} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (discount > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('قيمة الخصم:', style: TextStyle(color: Colors.green)),
                                Text('- $discount ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ],
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الإجمالي النهائي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('$displayTotal ج.م', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF007BFF))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. إدخال الكوبون
                  _buildSectionTitle('كوبون الخصم 🎁'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponController,
                          decoration: InputDecoration(
                            hintText: 'أدخل كود الخصم...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000826),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: state is CheckoutCouponLoading
                            ? null
                            : () {
                          if (_couponController.text.isNotEmpty) {
                            cubit.applyCoupon(_couponController.text);
                          }
                        },
                        child: const Text('تفعيل', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 3. بيانات التوصيل (الجديدة)
                  _buildSectionTitle('بيانات التوصيل 🚚'),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'رقم الهاتف',
                              prefixIcon: const Icon(Icons.phone, color: Color(0xFF00D4FF)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (value) => value!.isEmpty ? 'برجاء إدخال رقم الهاتف' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'عنوان التوصيل بالتفصيل',
                              prefixIcon: const Icon(Icons.location_on, color: Color(0xFF00D4FF)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (value) => value!.isEmpty ? 'برجاء إدخال العنوان' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. طريقة الدفع
                  _buildSectionTitle('طريقة الدفع 💳'),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('الدفع عند الاستلام', style: TextStyle(fontWeight: FontWeight.bold)),
                          value: 'cash',
                          groupValue: _selectedPaymentMethod,
                          activeColor: const Color(0xFF00D4FF),
                          onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                        ),
                        const Divider(height: 1),
                        RadioListTile<String>(
                          title: const Text('الدفع أونلاين (بطاقة / محفظة)', style: TextStyle(fontWeight: FontWeight.bold)),
                          value: 'online',
                          groupValue: _selectedPaymentMethod,
                          activeColor: const Color(0xFF00D4FF),
                          onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 5. زرار الدفع الرئيسي
                  BlocBuilder<CartCubit, CartState>(
                    bloc: getIt<CartCubit>(),
                    builder: (context, cartState) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4FF),
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: cartState is CartLoading ? null : () {
                          if (_formKey.currentState!.validate()) {
                            if (_selectedPaymentMethod == 'online') {
                              // 👇 هنا مكان كود بيموب اللي هنعمله الخطوة الجاية
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('جاري التحويل لبوابة Paymob... 💳')),
                              );
                            } else {
                              // 👇 تنفيذ الدفع كاش
                              getIt<CartCubit>().checkout(
                                address: _addressController.text,
                                phone: _phoneController.text,
                                finalTotal: displayTotal,
                                paymentMethod: 'Cash',
                              );
                            }
                          }
                        },
                        child: cartState is CartLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('تأكيد الطلب الآن', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF000826))),
    );
  }
}