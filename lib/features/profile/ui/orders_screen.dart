import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/order_cubit.dart';
import '../logic/order_state.dart';
import '../data/models/order_model.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('سجل الطلبات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          backgroundColor: const Color(0xFF000826),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocConsumer<OrderCubit, OrderState>(
          listener: (context, state) {
            if (state is OrderError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('حدث خطأ: ${state.error}'), backgroundColor: Colors.red),
              );
            }
          },
          builder: (context, state) {
            if (state is OrderLoading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF000826)));
            }

            if (state is OrderLoaded) {
              final orders = state.orders;
              if (orders.isEmpty) {
                return const Center(child: Text('لا توجد طلبات حتى الآن 📭', style: TextStyle(fontSize: 18, color: Colors.grey)));
              }

              return ListView.builder(
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

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                displayOrderNumber,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF000826)),
                              ),
                              Text(
                                '${order.date.day}/${order.date.month}/${order.date.year}',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  productsSummary,
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'الإجمالي: ${order.totalPrice.toStringAsFixed(2)} ج.م',
                            style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const Divider(height: 24),

                          _buildOrderTracker(order.status),

                          // 👈 زر الإلغاء يظهر فقط في حالة الـ Pending
                          if (order.status.toLowerCase() == 'pending') ...[
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _showCancelConfirmation(context, order.id),
                                icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                label: const Text('إلغاء الطلب', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // نافذة تأكيد الإلغاء
  void _showCancelConfirmation(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('تأكيد الإلغاء', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text('هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟ لا يمكن التراجع عن هذه الخطوة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تراجع', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext); // إغلاق النافذة
                context.read<OrderCubit>().cancelOrder(orderId); // تنفيذ الإلغاء
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('نعم، قم بالإلغاء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      case 'cancelled': return const Center(child: Text('تم إلغاء الطلب ❌', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)));
      default: currentStep = 0;
    }

    final steps = [
      {'title': 'الطلب', 'icon': Icons.receipt_long},
      {'title': 'التجهيز', 'icon': Icons.inventory_2_outlined},
      {'title': 'الشحن', 'icon': Icons.local_shipping_outlined},
      {'title': 'التوصيل', 'icon': Icons.check_circle_outline},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (index) {
        final isActive = index <= currentStep;
        return Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isActive ? const Color(0xFF00D4FF) : Colors.grey.shade300,
              child: Icon(steps[index]['icon'] as IconData, size: 16, color: isActive ? Colors.white : Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              steps[index]['title'] as String,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.black87 : Colors.grey,
              ),
            ),
          ],
        );
      }),
    );
  }
}