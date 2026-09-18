import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 ضروري لجلب الـ userId
import '../../../core/routing/routes.dart';
import '../../../core/di/dependency_injection.dart';
import '../../cart/logic/cart_cubit.dart';
import '../../cart/logic/cart_state.dart';
import '../logic/checkout_cubit.dart';
import '../data/models/address_model.dart';
import 'addresses_screen.dart';
import 'paymob_webview_screen.dart';

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
  final TextEditingController _walletPhoneController = TextEditingController();

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
    _walletPhoneController.dispose();
    super.dispose();
  }

  Future<void> _openAddressPicker() async {
    final AddressModel? selectedAddress = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressesScreen(isPickerMode: true),
      ),
    );

    if (selectedAddress != null) {
      setState(() {
        _phoneController.text = selectedAddress.phone;
        _addressController.text = selectedAddress.fullAddressText;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اختيار العنوان بنجاح ✅', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.blue),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('إتمام الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<CheckoutCubit, CheckoutState>(
        listener: (context, state) async {
          // 1. حالات الكوبون
          if (state is CheckoutCouponApplied) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تفعيل الكوبون! 🎉', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
            );
          } else if (state is CheckoutCouponError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
            );
          }

          // 2. 🌟 حالة نجاح الأوردر ونظام الـ FIFO
          if (state is CheckoutOrderSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تسجيل الطلب وخصم المخزون بنجاح! 🚀', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
            );

            // 👇 تم تفعيل دالة تفريغ السلة هنا
            getIt<CartCubit>().clearCart();

            context.pushReplacement(Routes.orders);
          } else if (state is CheckoutOrderError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
            );
          }

          // 3. حالات الدفع أونلاين
          if (state is CheckoutPaymobSuccess) {
            final bool? paymentResult = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaymobWebviewScreen(paymentKey: state.paymentKey),
              ),
            );

            if (paymentResult == true && context.mounted) {
              final checkoutCubit = context.read<CheckoutCubit>();
              double finalTotal = checkoutCubit.appliedCoupon != null
                  ? checkoutCubit.subTotal - ((checkoutCubit.subTotal * checkoutCubit.appliedCoupon!.discountPercentage) / 100)
                  : checkoutCubit.subTotal;

              // 👇 توجيه الطلب لنظام الـ FIFO بعد نجاح الدفع
              checkoutCubit.placeOrder(
                userId: FirebaseAuth.instance.currentUser?.uid ?? 'guest',
                cartItems: getIt<CartCubit>().cartItemsAsMap,
                totalSellingAmount: finalTotal,
                shippingAddress: {
                  'address': _addressController.text.trim(),
                  'phone': _phoneController.text.trim(),
                },
                paymentMethod: 'Online - Card',
              );
            } else if (paymentResult == false && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إلغاء أو فشل عملية الدفع بالفيزا ❌', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
              );
            }
          } else if (state is CheckoutWalletSuccess) {
            final bool? paymentResult = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaymobWebviewScreen(url: state.redirectUrl),
              ),
            );

            if (paymentResult == true && context.mounted) {
              final checkoutCubit = context.read<CheckoutCubit>();
              double finalTotal = checkoutCubit.appliedCoupon != null
                  ? checkoutCubit.subTotal - ((checkoutCubit.subTotal * checkoutCubit.appliedCoupon!.discountPercentage) / 100)
                  : checkoutCubit.subTotal;

              // 👇 توجيه الطلب لنظام الـ FIFO بعد نجاح الدفع بالمحفظة
              checkoutCubit.placeOrder(
                userId: FirebaseAuth.instance.currentUser?.uid ?? 'guest',
                cartItems: getIt<CartCubit>().cartItemsAsMap,
                totalSellingAmount: finalTotal,
                shippingAddress: {
                  'address': _addressController.text.trim(),
                  'phone': _phoneController.text.trim(),
                },
                paymentMethod: 'Online - Wallet',
              );
            } else if (paymentResult == false && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إلغاء أو فشل عملية الدفع بالمحفظة ❌', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
              );
            }
          } else if (state is CheckoutPaymobError || state is CheckoutWalletError) {
            final errorMsg = state is CheckoutPaymobError
                ? state.error
                : (state as CheckoutWalletError).error;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
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
                            const Text('المجموع الفرعي:', style: TextStyle(fontFamily: 'Cairo')),
                            Text('${cubit.subTotal} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                          ],
                        ),
                        if (discount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('قيمة الخصم:', style: TextStyle(color: Colors.green, fontFamily: 'Cairo')),
                              Text('- $discount ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontFamily: 'Cairo')),
                            ],
                          ),
                        ],
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الإجمالي النهائي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                            Text('$displayTotal ج.م', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF007BFF), fontFamily: 'Cairo')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

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
                      child: const Text('تفعيل', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle('بيانات التوصيل 🚚'),
                    TextButton.icon(
                      onPressed: _openAddressPicker,
                      icon: const Icon(Icons.bookmark_border, size: 18, color: Color(0xFF007BFF)),
                      label: const Text('اختيار من عناويني', style: TextStyle(color: Color(0xFF007BFF), fontSize: 13, fontFamily: 'Cairo')),
                    ),
                  ],
                ),
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
                            labelText: 'رقم الهاتف للتواصل',
                            prefixIcon: const Icon(Icons.phone, color: Color(0xFF00D4FF)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (value) => value!.isEmpty ? 'برجاء إدخال رقم الهاتف' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
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

                _buildSectionTitle('طريقة الدفع 💳'),
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('الدفع عند الاستلام', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        value: 'cash',
                        groupValue: _selectedPaymentMethod,
                        activeColor: const Color(0xFF00D4FF),
                        onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: const Text('الدفع بالفيزا (Online Card)', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        value: 'card',
                        groupValue: _selectedPaymentMethod,
                        activeColor: const Color(0xFF00D4FF),
                        onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: const Text('المحفظة الإلكترونية', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        value: 'wallet',
                        groupValue: _selectedPaymentMethod,
                        activeColor: const Color(0xFF00D4FF),
                        onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                      ),
                      if (_selectedPaymentMethod == 'wallet') ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: TextFormField(
                            controller: _walletPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'رقم المحفظة الإلكترونية (مثال: 010xxxxxxxx)',
                              prefixIcon: const Icon(Icons.account_balance_wallet, color: Color(0xFF00D4FF)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (value) {
                              if (_selectedPaymentMethod == 'wallet' && (value == null || value.isEmpty)) {
                                return 'برجاء إدخال رقم المحفظة الإلكترونية';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 👇 زر تأكيد الطلب أصبح يعتمد على حالة CheckoutOrderLoading
                Builder(
                  builder: (context) {
                    bool isLoading = state is CheckoutOrderLoading ||
                        state is CheckoutPaymobLoading ||
                        state is CheckoutWalletLoading;

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4FF),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isLoading ? null : () {
                        if (_formKey.currentState!.validate()) {
                          if (_selectedPaymentMethod == 'card') {
                            cubit.getPaymobPaymentKey(
                              totalAmount: displayTotal,
                              phone: _phoneController.text.trim(),
                              address: _addressController.text.trim(),
                              items: getIt<CartCubit>().cartItemsAsMap,
                            );
                          } else if (_selectedPaymentMethod == 'wallet') {
                            cubit.payWithWallet(
                              totalAmount: displayTotal,
                              walletPhoneNumber: _walletPhoneController.text.trim(),
                            );
                          } else {
                            // 👇 التنفيذ المباشر لنظام الـ FIFO عند اختيار الكاش
                            cubit.placeOrder(
                              userId: FirebaseAuth.instance.currentUser?.uid ?? 'guest',
                              cartItems: getIt<CartCubit>().cartItemsAsMap,
                              totalSellingAmount: displayTotal,
                              shippingAddress: {
                                'address': _addressController.text.trim(),
                                'phone': _phoneController.text.trim(),
                              },
                              paymentMethod: 'Cash',
                            );
                          }
                        }
                      },
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('تأكيد الطلب الآن', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF000826), fontFamily: 'Cairo')),
    );
  }
}