import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/order_cubit.dart';
import '../logic/order_state.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  // 👈 دالة الشارة العلوية المحدثة للحالات الخمسة
  Widget _buildOrderStatus(String status) {
    String text;
    Color color;

    switch (status.toLowerCase()) {
      case 'pending':
        text = 'قيد الانتظار';
        color = Colors.orange;
        break;
      case 'processing':
        text = 'جاري التجهيز';
        color = Colors.blue;
        break;
      case 'shipped':
        text = 'تم الشحن';
        color = Colors.deepPurple;
        break;
      case 'delivered':
        text = 'تم التوصيل';
        color = Colors.green;
        break;
      case 'cancelled':
        text = 'ملغي';
        color = Colors.red;
        break;
      default:
        text = status;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  // 👈 بناء الخط الزمني التفاعلي المحدث (4 خطوات: الطلب، التجهيز، الشحن، التوصيل)
  Widget _buildTrackingTimeline(String status) {
    final String currentStatus = status.toLowerCase();

    final isCancelled = currentStatus == 'cancelled';
    final isProcessing = currentStatus == 'processing' || currentStatus == 'shipped' || currentStatus == 'delivered';
    final isShipped = currentStatus == 'shipped' || currentStatus == 'delivered';
    final isDelivered = currentStatus == 'delivered';

    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('تم إلغاء هذا الطلب', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineStep(Icons.receipt_long, 'الطلب', true),
        _buildTimelineDivider(isProcessing),
        _buildTimelineStep(Icons.inventory_2, 'التجهيز', isProcessing),
        _buildTimelineDivider(isShipped),
        _buildTimelineStep(Icons.local_shipping, 'الشحن', isShipped),
        _buildTimelineDivider(isDelivered),
        _buildTimelineStep(Icons.check_circle, 'التوصيل', isDelivered),
      ],
    );
  }

  // تصميم دائرة الخط الزمني
  Widget _buildTimelineStep(IconData icon, String label, bool isActive) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: isActive ? const Color(0xFF00D4FF) : Colors.grey.shade300,
            child: Icon(icon, size: 14, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? const Color(0xFF000826) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // تصميم الخط الواصل بين الدوائر
  Widget _buildTimelineDivider(bool isActive) {
    return Container(
      width: 15,
      margin: const EdgeInsets.only(top: 13), // لضبط المحاذاة مع منتصف الدوائر
      height: 2,
      color: isActive ? const Color(0xFF00D4FF) : Colors.grey.shade300,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('سجل الطلبات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocBuilder<OrderCubit, OrderState>(
        builder: (context, state) {
          if (state is OrderLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)));
          }

          if (state is OrderError) {
            return Center(child: Text('حدث خطأ: ${state.error}', style: const TextStyle(color: Colors.red)));
          }

          if (state is OrderLoaded) {
            final orders = state.orders;

            if (orders.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('لا توجد طلبات سابقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('طلب رقم: ${order.id.substring(0, 8)}#', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            _buildOrderStatus(order.status),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('التاريخ:', style: TextStyle(color: Colors.grey)),
                            Text(order.date, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الإجمالي:', style: TextStyle(color: Colors.grey)),
                            Text('${order.totalPrice} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007BFF), fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // عرض الخط الزمني المحدث
                        _buildTrackingTimeline(order.status),
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
    );
  }
}