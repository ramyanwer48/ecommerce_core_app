import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/order_cubit.dart';
import '../logic/order_state.dart';
import '../data/models/order_model.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  // 🚀 ألوان الهوية البصرية الأساسية
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = const Color(0xFFFF9F0A);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA), // خلفية ناعمة جداً
        appBar: AppBar(
          title: const Text('سجل الطلبات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo', fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy, // 👈 كحلي فخم
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: BlocConsumer<OrderCubit, OrderState>(
          listener: (context, state) {
            if (state is OrderError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('حدث خطأ: ${state.error}', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
              );
            }
          },
          builder: (context, state) {
            if (state is OrderLoading) {
              return Center(child: CircularProgressIndicator(color: brandOrange)); // 👈 برتقالي
            }

            if (state is OrderLoaded) {
              final orders = state.orders;
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('لا توجد طلبات حتى الآن', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];

                  final String datePrefix = '${order.date.year.toString().substring(2)}${order.date.month.toString().padLeft(2, '0')}${order.date.day.toString().padLeft(2, '0')}';
                  final String displayOrderNumber = order.orderNumber > 0
                      ? 'ORD-$datePrefix-${order.orderNumber}'
                      : 'ORD-${order.id.substring(0, 6).toUpperCase()}';

                  String productsSummary = '';
                  if (order.items.isNotEmpty) {
                    if (order.items.length == 1) {
                      productsSummary = order.items.first.name;
                    } else {
                      productsSummary = '${order.items.first.name} + ${order.items.length - 1} منتج آخر';
                    }
                  } else {
                    productsSummary = 'منتجات غير محددة';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🚀 الهيدر: رقم الطلب والتاريخ
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: primaryNavy.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  displayOrderNumber,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy, fontFamily: 'Cairo', letterSpacing: 0.5),
                                ),
                              ),
                              Text(
                                '${order.date.year}/${order.date.month.toString().padLeft(2, '0')}/${order.date.day.toString().padLeft(2, '0')}',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 🚀 ملخص المنتجات
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
                                child: Icon(Icons.shopping_bag_outlined, size: 20, color: primaryNavy),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  productsSummary,
                                  style: const TextStyle(fontSize: 14, color: Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 🚀 الإجمالي
                          Row(
                            children: [
                              Text('الإجمالي: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                              Text(
                                '${order.totalPrice.toStringAsFixed(2)} ج.م',
                                style: TextStyle(color: brandOrange, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo'),
                              ),
                            ],
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(height: 1, thickness: 1),
                          ),

                          // 🚀 شريط الحالات (التتبع)
                          _buildOrderTracker(order.status),

                          // 🚀 زر الإلغاء
                          if (order.status.toLowerCase() == 'pending') ...[
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _showCancelConfirmation(context, order.id);
                                },
                                icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                                label: const Text('إلغاء الطلب', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: Colors.red.withOpacity(0.05),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              const Text('تأكيد الإلغاء', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
            ],
          ),
          content: const Text('هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟\nلا يمكن التراجع عن هذه الخطوة.', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.5)),
          actionsPadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تراجع', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(dialogContext);
                context.read<OrderCubit>().cancelOrder(orderId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('نعم، إلغاء الطلب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTracker(String status) {
    int currentStep = 0;
    switch (status.toLowerCase()) {
      case 'pending': currentStep = 0; break;
      case 'processing': currentStep = 1; break;
      case 'shipped': currentStep = 2; break;
      case 'delivered': currentStep = 3; break;
      case 'cancelled':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text('تم إلغاء الطلب', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo')),
            ],
          ),
        );
      default: currentStep = 0;
    }

    final steps = [
      {'title': 'الطلب', 'icon': Icons.receipt_long_rounded},
      {'title': 'التجهيز', 'icon': Icons.inventory_2_rounded},
      {'title': 'الشحن', 'icon': Icons.local_shipping_rounded},
      {'title': 'التوصيل', 'icon': Icons.check_circle_rounded},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (index) {
        final isActive = index <= currentStep;

        return Expanded(
          child: Row(
            children: [
              // 🚀 الدائرة
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive ? brandOrange : Colors.grey.shade100, // 👈 برتقالي لو نشط
                      shape: BoxShape.circle,
                      border: Border.all(color: isActive ? brandOrange : Colors.grey.shade300, width: 2),
                      boxShadow: isActive ? [BoxShadow(color: brandOrange.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : [],
                    ),
                    child: Icon(steps[index]['icon'] as IconData, size: 18, color: isActive ? Colors.white : Colors.grey.shade400),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    steps[index]['title'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Cairo',
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      color: isActive ? primaryNavy : Colors.grey.shade500, // 👈 كحلي للنص
                    ),
                  ),
                ],
              ),
              // 🚀 الخط المتصل بين الدواير
              if (index < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
                    decoration: BoxDecoration(
                      color: index < currentStep ? brandOrange : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}