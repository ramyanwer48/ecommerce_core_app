import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../profile/data/models/order_model.dart';
import '../logic/admin_orders_cubit.dart';
import '../logic/admin_orders_state.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {

  @override
  void initState() {
    super.initState();
    context.read<AdminOrdersCubit>().fetchAllOrders();
  }

  Future<void> _automateLedgerEntry(OrderModel order) async {
    try {
      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      DocumentSnapshot orderDoc = await firestore.collection('orders').doc(order.id).get();
      if (!orderDoc.exists) return;
      var data = orderDoc.data() as Map<String, dynamic>;

      String customerName = '';
      if (data.containsKey('shippingAddress') && data['shippingAddress'] is Map) {
        var addr = data['shippingAddress'];
        customerName = '${addr['firstName'] ?? ''} ${addr['lastName'] ?? ''}'.trim();
        if (customerName.isEmpty) customerName = (addr['name'] ?? addr['fullName'] ?? '').toString().trim();
      }
      if (customerName.isEmpty) customerName = (data['userName'] ?? data['customerName'] ?? data['name'] ?? '').toString().trim();
      if (customerName.isEmpty) customerName = 'عميل أونلاين (${order.id.substring(0, 4)})';

      String phone = order.phone;
      double price = order.totalPrice;
      if (price <= 0) return;

      QuerySnapshot customerSnap = await firestore.collection('customers').where('name', isEqualTo: customerName).get();
      DocumentReference customerRef;
      String customerId;

      if (customerSnap.docs.isEmpty) {
        customerRef = firestore.collection('customers').doc();
        customerId = customerRef.id;
        batch.set(customerRef, {
          'name': customerName,
          'phone': phone,
          'balance': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        customerRef = customerSnap.docs.first.reference;
        customerId = customerSnap.docs.first.id;
      }

      DocumentReference saleRef = firestore.collection('ledger_entries').doc('order_${order.id}');
      batch.set(saleRef, {
        'partnerId': customerId,
        'partnerName': customerName,
        'type': 'sale',
        'amount': price,
        'date': FieldValue.serverTimestamp(),
        'note': 'أوردر أونلاين رقم: ${order.id.substring(0, 5)}',
      }, SetOptions(merge: true));

      DocumentReference receiptRef = firestore.collection('ledger_entries').doc('auto_receipt_${order.id}');
      batch.set(receiptRef, {
        'partnerId': customerId,
        'partnerName': customerName,
        'type': 'receipt',
        'amount': price,
        'date': FieldValue.serverTimestamp(),
        'note': 'تحصيل أوتوماتيكي (أونلاين/تم التسليم)',
      }, SetOptions(merge: true));

      await batch.commit();
      debugPrint('Automation Success: Ledger updated for ${order.id}');
    } catch (e) {
      debugPrint('Automation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          // 🚀 التعديل: المسمى الاحترافي الجديد
          title: const Text('إدارة طلبات الأونلاين', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
          centerTitle: true,
          backgroundColor: const Color(0xFF000826),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocConsumer<AdminOrdersCubit, AdminOrdersState>(
          listener: (context, state) {
            if (state is AdminOrderStatusUpdated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحديث حالة الطلب بنجاح! 🚀', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
              );
            } else if (state is AdminOrdersError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
              );
            }
          },
          builder: (context, state) {
            if (state is AdminOrdersLoading || state is AdminOrdersInitial) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF000826)));
            }

            if (state is AdminOrdersLoaded) {
              final orders = state.orders;
              if (orders.isEmpty) {
                return const Center(
                  child: Text('لا توجد طلبات أونلاين حتى الآن 📭', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];

                  final List<String> validStatuses = ['Pending', 'Processing', 'Waybill', 'Shipped', 'Delivered', 'Cancelled'];
                  final currentStatus = validStatuses.contains(order.status) ? order.status : 'Pending';

                  final String datePrefix = '${order.date.year.toString().substring(2)}-${order.date.month.toString().padLeft(2, '0')}-${order.date.day.toString().padLeft(2, '0')}';

                  final String displayOrderNumber = order.orderNumber > 0
                      ? 'ORD-[$datePrefix]-${order.orderNumber}'
                      : 'ORD-${order.id.substring(0, order.id.length > 6 ? 6 : order.id.length).toUpperCase()}';

                  final String formattedDate = '${order.date.day}/${order.date.month}/${order.date.year}';
                  final currentStatusConfig = _getStatusConfig(currentStatus);

                  String displayPaymentMethod = order.paymentMethod;
                  if (displayPaymentMethod.toLowerCase() == 'cash' || displayPaymentMethod == 'كاش') {
                    displayPaymentMethod = 'الدفع عند الاستلام';
                  }

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.orange.shade600.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                      displayOrderNumber,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF000826))
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(displayPaymentMethod, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, fontFamily: 'Cairo')),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Icon(Icons.phone_iphone, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(child: Text(order.phone, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(child: Text(order.address, style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.3, fontFamily: 'Cairo'))),
                            ],
                          ),

                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('المنتجات المطلوبة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
                                const SizedBox(height: 8),
                                ...order.items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${item.quantity}x ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                                      Expanded(child: Text('${item.name}', style: const TextStyle(fontSize: 13, fontFamily: 'Cairo'))),
                                      Text('${item.unitPrice} ج', style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              children: [
                                Text('الإجمالي: ${order.totalPrice.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo')),
                                const SizedBox(width: 16),
                                Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('تغيير الحالة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                              Flexible(
                                child: InkWell(
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
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(child: Text(currentStatusConfig['text'], overflow: TextOverflow.ellipsis, style: TextStyle(color: currentStatusConfig['color'], fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'))),
                                        const SizedBox(width: 4),
                                        Icon(Icons.keyboard_arrow_down, color: currentStatusConfig['color'], size: 18),
                                      ],
                                    ),
                                  ),
                                ),
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
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'Pending': return {'text': 'قيد الانتظار ⏳', 'color': Colors.orange};
      case 'Processing': return {'text': 'جاري التجهيز 📦', 'color': Colors.blue};
      case 'Waybill': return {'text': 'بوليصة 🖨', 'color': Colors.cyan};
      case 'Shipped': return {'text': 'تم الشحن 🚚', 'color': Colors.deepPurple};
      case 'Delivered': return {'text': 'تم التوصيل ✅', 'color': Colors.green};
      case 'Cancelled': return {'text': 'ملغي ❌', 'color': Colors.red};
      default: return {'text': 'قيد الانتظار ⏳', 'color': Colors.orange};
    }
  }

  void _showStatusModal(BuildContext context, OrderModel order, String currentStatus) {
    final List<String> statuses = ['Pending', 'Processing', 'Waybill', 'Shipped', 'Delivered', 'Cancelled'];
    final adminOrdersCubit = context.read<AdminOrdersCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bottomSheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 20,
                left: 16,
                right: 16,
                top: 20
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 16),
                  const Text('تحديث حالة الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  const SizedBox(height: 16),
                  ...statuses.map((status) {
                    final config = _getStatusConfig(status);
                    final isSelected = currentStatus == status;

                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      tileColor: isSelected ? config['color'].withValues(alpha: 0.1) : Colors.transparent,
                      leading: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: config['color']),
                      title: Text(config['text'], style: TextStyle(color: config['color'], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontFamily: 'Cairo')),
                      onTap: () async {
                        Navigator.pop(bottomSheetContext);
                        if (!isSelected) {
                          adminOrdersCubit.updateStatus(order, status);
                          if (status == 'Delivered') {
                            await _automateLedgerEntry(order);
                          }
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}