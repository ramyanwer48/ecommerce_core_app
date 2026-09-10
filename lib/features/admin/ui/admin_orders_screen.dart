import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/admin_orders_cubit.dart';
import '../logic/admin_orders_state.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('إدارة طلبات العملاء', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<AdminOrdersCubit, AdminOrdersState>(
        listener: (context, state) {
          if (state is AdminOrderStatusUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تحديث حالة الطلب بنجاح! 🚀'), backgroundColor: Colors.green),
            );
          } else if (state is AdminOrdersError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminOrdersLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AdminOrdersLoaded) {
            final orders = state.orders;
            if (orders.isEmpty) {
              return const Center(child: Text('لا توجد طلبات حتى الآن', style: TextStyle(fontSize: 18, color: Colors.grey)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('رقم الطلب: ${order.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

                        // قسم الهاتف والعنوان الجديد
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(order.phone, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Text(order.address, style: const TextStyle(fontSize: 14, color: Colors.black87))),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Text('الإجمالي: ${order.totalPrice} ج.م', style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold)),
                        Text('التاريخ: ${order.date}', style: const TextStyle(color: Colors.grey)),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('تغيير الحالة:', style: TextStyle(fontWeight: FontWeight.bold)),
                            DropdownButton<String>(
                              value: ['Pending', 'Delivered', 'Cancelled'].contains(order.status) ? order.status : 'Pending',
                              underline: Container(height: 2, color: const Color(0xFF00D4FF)),
                              items: const [
                                DropdownMenuItem(value: 'Pending', child: Text('قيد التنفيذ ⏳', style: TextStyle(color: Colors.orange))),
                                DropdownMenuItem(value: 'Delivered', child: Text('تم التوصيل ✅', style: TextStyle(color: Colors.green))),
                                DropdownMenuItem(value: 'Cancelled', child: Text('ملغي ❌', style: TextStyle(color: Colors.red))),
                              ],
                              onChanged: (newStatus) {
                                if (newStatus != null && newStatus != order.status) {
                                  context.read<AdminOrdersCubit>().updateStatus(order.id, order.userId, newStatus);
                                }
                              },
                            ),
                          ],
                        ),
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