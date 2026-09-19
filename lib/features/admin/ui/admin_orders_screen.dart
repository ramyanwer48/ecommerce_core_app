import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../profile/data/models/order_model.dart';
import '../logic/admin_orders_cubit.dart';
import '../logic/admin_orders_state.dart';
import '../../../core/utils/printer_bottom_sheet.dart'; // 👈 مسار استدعاء نافذة الطباعة الحرارية

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // 👈 فرض اتجاه الواجهة من اليمين لليسار
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('إدارة طلبات العملاء', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          backgroundColor: const Color(0xFF000826),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocConsumer<AdminOrdersCubit, AdminOrdersState>(
          listener: (context, state) {
            if (state is AdminOrderStatusUpdated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تحديث حالة الطلب وإدارة المخزون بنجاح! 🚀'),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is AdminOrdersError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is AdminOrdersLoading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF000826)));
            }

            if (state is AdminOrdersLoaded) {
              final orders = state.orders;
              if (orders.isEmpty) {
                return const Center(
                  child: Text(
                    'لا توجد طلبات حتى الآن 📭',
                    style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];

                  // الحالات المسموح بها وإعداداتها
                  final List<String> validStatuses = ['Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];
                  final currentStatus = validStatuses.contains(order.status) ? order.status : 'Pending';

                  // 👈 تنسيق رقم الطلب المسلسل الاحترافي (مدمج بالتاريخ)
                  final String datePrefix = '${order.date.year.toString().substring(2)}${order.date.month.toString().padLeft(2, '0')}${order.date.day.toString().padLeft(2, '0')}';
                  final String displayOrderNumber = order.orderNumber > 0
                      ? 'ORD-$datePrefix-${order.orderNumber}'
                      : 'ORD-${order.id.substring(0, order.id.length > 6 ? 6 : order.id.length).toUpperCase()}';

                  // تنسيق التاريخ
                  final String formattedDate = '${order.date.day}/${order.date.month}/${order.date.year}';

                  // إعدادات واجهة الحالة الحالية
                  final currentStatusConfig = _getStatusConfig(currentStatus);

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. رأس الكارت: رقم الطلب المسلسل + طريقة الدفع
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                displayOrderNumber,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF000826)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  order.paymentMethod,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          // 2. رقم التليفون
                          Row(
                            children: [
                              const Icon(Icons.phone_iphone, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                order.phone,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 3. العنوان
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.address,
                                  style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 4. الإجمالي والتاريخ
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الإجمالي: ${order.totalPrice.toStringAsFixed(2)} ج.م',
                                style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                formattedDate,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),

                          const Divider(height: 24),

                          // 5. زر تغيير الحالة الاحترافي (بدون Dropdown)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('تغيير الحالة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _showStatusModal(context, order, currentStatus),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: currentStatusConfig['color'].withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(10),
                                    color: currentStatusConfig['color'].withValues(alpha: 0.1),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        currentStatusConfig['text'],
                                        style: TextStyle(
                                          color: currentStatusConfig['color'],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.keyboard_arrow_down, color: currentStatusConfig['color'], size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),


                          // 6. 🖨️ زر الطباعة الحرارية
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showPrinterBottomSheet(
                                  context: context,
                                  orderNumber: displayOrderNumber,                 // 👈 تمرير المتغير المنسق كاملاً (ORD-...)
                                  customerName: 'عميل المتجر',
                                  phone: order.phone,
                                  address: order.address,
                                  subtotal: order.subtotal,
                                  discountAmount: order.discountAmount,
                                  totalAmount: order.totalPrice,
                                  paymentMethod: order.paymentMethod,
                                  products: order.items.map((item) => {
                                    'name': item.name,
                                    'quantity': item.quantity,
                                    'unitPrice': item.unitPrice,
                                  }).toList(),
                                );
                              },
                              icon: const Icon(Icons.print_rounded, size: 20),
                              label: const Text('طباعة بوليصة الشحن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF000826),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
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
      ),
    );
  }

  // 👈 دالة مساعدة لترجيع الإعدادات (نصوص وألوان) بناءً على الحالة
  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'Pending': return {'text': 'قيد الانتظار ⏳', 'color': Colors.orange};
      case 'Processing': return {'text': 'جاري التجهيز 📦', 'color': Colors.blue};
      case 'Shipped': return {'text': 'تم الشحن 🚚', 'color': Colors.deepPurple};
      case 'Delivered': return {'text': 'تم التوصيل ✅', 'color': Colors.green};
      case 'Cancelled': return {'text': 'ملغي ❌', 'color': Colors.red};
      default: return {'text': 'قيد الانتظار ⏳', 'color': Colors.orange};
    }
  }

  // 👈 دالة عرض النافذة السفلية (Modal Bottom Sheet) لاختيار الحالة
  void _showStatusModal(BuildContext context, OrderModel order, String currentStatus) {
    final List<String> statuses = ['Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 16),
                const Text('تحديث حالة الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...statuses.map((status) {
                  final config = _getStatusConfig(status);
                  final isSelected = currentStatus == status;

                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tileColor: isSelected ? config['color'].withValues(alpha: 0.1) : Colors.transparent,
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: config['color'],
                    ),
                    title: Text(
                      config['text'],
                      style: TextStyle(
                        color: config['color'],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(bottomSheetContext); // إغلاق النافذة
                      if (!isSelected) {
                        // تحديث الحالة إذا تم اختيار حالة مختلفة
                        context.read<AdminOrdersCubit>().updateStatus(order.id, order.userId, status);
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}