import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/order_cubit.dart';
import '../logic/order_state.dart';
import '../data/models/order_model.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = const Color(0xFFFF9F0A);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('سجل الطلبات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo', fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: BlocConsumer<OrderCubit, OrderState>(
          listener: (context, state) {
            // 🚀 تم حذف السطر اللي كان بيقفل الشاشة بالغلط
            if (state is OrderError) {
              // رسالة الخطأ الأنيقة بدلاً من الشريط الأحمر
              showDialog(
                context: context,
                builder: (context) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('تنبيه', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    content: Text(state.error, style: const TextStyle(fontFamily: 'Cairo', height: 1.5)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('حسناً', style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is OrderLoading) {
              return Center(child: CircularProgressIndicator(color: brandOrange));
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
                      ? 'ORD-[$datePrefix]-${order.orderNumber}'
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

                  final int remainingReturnDays = _getRemainingReturnDays(order.date, maxDays: 14);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: brandOrange, width: 1.2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatusBadge(order.status),
                              Text(
                                displayOrderNumber,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryNavy, fontFamily: 'Cairo', letterSpacing: 0.5),
                              ),
                            ],
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                          ),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('المنتجات المطلوبة:', style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.shopping_bag_outlined, size: 18, color: brandOrange),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        productsSummary,
                                        style: const TextStyle(fontSize: 14, color: Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontFamily: 'Cairo'),
                                  children: [
                                    const TextSpan(text: 'الإجمالي: ', style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.bold)),
                                    TextSpan(text: '${order.totalPrice.toStringAsFixed(2)} ج.م', style: TextStyle(color: brandOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  '\u200E${order.date.day.toString().padLeft(2, '0')}/${order.date.month.toString().padLeft(2, '0')}/${order.date.year}',
                                  style: const TextStyle(color: Colors.black87, fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          _buildOrderTracker(order.status),

                          if (order.status.toLowerCase() == 'pending') ...[
                            const SizedBox(height: 20),
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
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  backgroundColor: Colors.red.withOpacity(0.05),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],

                          if (order.status.toLowerCase() == 'delivered' && remainingReturnDays >= 0) ...[
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _showReturnConfirmation(context, order);
                                },
                                icon: const Icon(Icons.assignment_return_rounded, color: Colors.white, size: 20),
                                label: Text(
                                    remainingReturnDays == 0
                                        ? 'طلب إرجاع (اليوم الأخير)'
                                        : 'طلب إرجاع (متبقي $remainingReturnDays يوم)',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  backgroundColor: brandOrange,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = brandOrange.withOpacity(0.15);
        textColor = brandOrange;
        text = 'قيد الانتظار';
        break;
      case 'processing':
        bgColor = Colors.blue.withOpacity(0.15);
        textColor = Colors.blue;
        text = 'جاري التجهيز';
        break;
      case 'waybill':
        bgColor = Colors.indigo.withOpacity(0.15);
        textColor = Colors.indigo;
        text = 'بوليصة الشحن';
        break;
      case 'shipped':
        bgColor = Colors.purple.withOpacity(0.15);
        textColor = Colors.purple;
        text = 'في الطريق';
        break;
      case 'delivered':
        bgColor = Colors.green.withOpacity(0.15);
        textColor = Colors.green;
        text = 'تم التسليم';
        break;
      case 'cancelled':
        bgColor = Colors.red.withOpacity(0.15);
        textColor = Colors.red;
        text = 'ملغي';
        break;
      case 'return requested':
        bgColor = Colors.orangeAccent.withOpacity(0.15);
        textColor = Colors.orange.shade800;
        text = 'جاري الإرجاع';
        break;
      case 'returned':
        bgColor = Colors.grey.withOpacity(0.15);
        textColor = Colors.grey.shade800;
        text = 'تم الإرجاع';
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.15);
        textColor = Colors.grey.shade700;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo')),
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

  void _showReturnConfirmation(BuildContext context, OrderModel order) {
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
                decoration: BoxDecoration(color: brandOrange.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.assignment_return, color: brandOrange),
              ),
              const SizedBox(width: 12),
              const Text('طلب إرجاع', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
            ],
          ),
          content: const Text(
              'هل تريد تقديم طلب لإرجاع هذا الطلب؟\nسيتم مراجعة الطلب من قبل الإدارة للتواصل معك وإتمام الإرجاع.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.5)
          ),
          actionsPadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تراجع', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(dialogContext); // قفل نافذة التأكيد

                // 🚀 إرسال الطلب للفايربيس
                context.read<OrderCubit>().requestReturn(order);

                // 🚀 ظهور نافذة النجاح الأنيقة في المنتصف بدلاً من الشريط السفلي
                showDialog(
                  context: context,
                  builder: (successContext) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: brandOrange.withOpacity(0.1), shape: BoxShape.circle),
                              child: Icon(Icons.check_circle_rounded, color: brandOrange, size: 48),
                            ),
                            const SizedBox(height: 16),
                            const Text('تم إرسال الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 20)),
                            const SizedBox(height: 8),
                            const Text(
                              'تم إرسال طلب المرتجع للإدارة بنجاح، سيتم مراجعته والتواصل معك قريباً.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black87, height: 1.5),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(successContext),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryNavy,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('حسناً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: brandOrange,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('تأكيد الطلب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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
      case 'waybill': currentStep = 2; break;
      case 'shipped': currentStep = 3; break;
      case 'delivered': currentStep = 4; break;
      case 'return requested': currentStep = 4; break;
      case 'returned': currentStep = 4; break;
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
      {'title': 'البوليصة', 'icon': Icons.print_rounded},
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
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isActive ? brandOrange : Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: isActive ? brandOrange : Colors.grey.shade300, width: 1.5),
                      boxShadow: isActive ? [BoxShadow(color: brandOrange.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : [],
                    ),
                    child: Icon(steps[index]['icon'] as IconData, size: 14, color: isActive ? Colors.white : Colors.grey.shade400),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    steps[index]['title'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Cairo',
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      color: isActive ? primaryNavy : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              if (index < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2.5,
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

  int _getRemainingReturnDays(DateTime date, {int maxDays = 14}) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    return maxDays - difference;
  }
}