import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../profile/data/models/order_model.dart';
import '../logic/admin_orders_cubit.dart';
import '../logic/admin_orders_state.dart';
import 'orders_archive_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  @override
  void initState() {
    super.initState();
    context.read<AdminOrdersCubit>().fetchAllOrders();
  }

  void _showArchiveConfirmationDialog(String actionType) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: brandOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.archive_rounded, color: brandOrange, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                actionType == 'Delivered' ? 'تم توصيل الطلب بنجاح' : 'تم إلغاء الطلب',
                style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
              ),
            ],
          ),
          content: Text(
            actionType == 'Delivered'
                ? 'تم تسجيل الأوردر كـ (تم التوصيل) ونقله تلقائياً إلى أرشيف الطلبات المكتملة.'
                : 'تم إلغاء الأوردر ونقله تلقائياً إلى أرشيف الطلبات الملغية.',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black87),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);
                context.read<AdminOrdersCubit>().fetchAllOrders(); // تحديث فوري للقائمة
              },
              child: const Text('حسناً، فهمت', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _automateLedgerEntry(OrderModel order) async {
    try {
      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      DocumentSnapshot orderDoc =
      await firestore.collection('orders').doc(order.id).get();
      if (!orderDoc.exists) return;
      var data = orderDoc.data() as Map<String, dynamic>;

      String customerName = '';
      if (data.containsKey('shippingAddress') &&
          data['shippingAddress'] is Map) {
        var addr = data['shippingAddress'];
        customerName =
            '${addr['firstName'] ?? ''} ${addr['lastName'] ?? ''}'.trim();
        if (customerName.isEmpty) {
          customerName =
              (addr['name'] ?? addr['fullName'] ?? '').toString().trim();
        }
      }
      if (customerName.isEmpty) {
        customerName =
            (data['userName'] ?? data['customerName'] ?? data['name'] ?? '')
                .toString()
                .trim();
      }
      if (customerName.isEmpty) {
        String shortId =
        order.id.length >= 4 ? order.id.substring(0, 4) : order.id;
        customerName = 'عميل أونلاين ($shortId)';
      }

      String phone = order.phone;
      double price = order.totalPrice;
      if (price <= 0) return;

      QuerySnapshot customerSnap = await firestore
          .collection('customers')
          .where('name', isEqualTo: customerName)
          .get();
      DocumentReference customerRef;
      String customerId;

      if (customerSnap.docs.isEmpty) {
        customerRef = firestore.collection('customers').doc();
        customerId = customerRef.id;
        batch.set(customerRef, {
          'id': customerId,
          'name': customerName,
          'phone': phone,
          'type': 'customer',
          'balance': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        customerRef = customerSnap.docs.first.reference;
        customerId = customerSnap.docs.first.id;
      }

      String shortOrderId =
      order.id.length >= 5 ? order.id.substring(0, 5) : order.id;

      DocumentReference saleRef =
      firestore.collection('ledger_entries').doc('order_${order.id}');
      batch.set(
        saleRef,
        {
          'partnerId': customerId,
          'accountId': customerId,
          'partnerName': customerName,
          'type': 'sale',
          'transactionType': 'online_sale',
          'amount': price,
          'date': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
          'note': 'أوردر أونلاين رقم: $shortOrderId',
        },
        SetOptions(merge: true),
      );

      DocumentReference receiptRef = firestore
          .collection('ledger_entries')
          .doc('auto_receipt_${order.id}');
      batch.set(
        receiptRef,
        {
          'partnerId': customerId,
          'accountId': customerId,
          'partnerName': customerName,
          'type': 'receipt',
          'transactionType': 'online_receipt',
          'amount': price,
          'date': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
          'note': 'تحصيل أوتوماتيكي (أونلاين/تم التسليم)',
        },
        SetOptions(merge: true),
      );

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
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OrdersArchiveScreen()),
                  );
                  if (mounted) {
                    context.read<AdminOrdersCubit>().fetchAllOrders();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: brandOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.archive_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'الأرشيف',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/admin');
                }
              },
            ),
            const SizedBox(width: 8),
          ],
          title: const Text(
            'إدارة طلبات الأونلاين',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Cairo',
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          backgroundColor: primaryNavy,
        ),
        body: BlocConsumer<AdminOrdersCubit, AdminOrdersState>(
          listener: (context, state) {
            if (state is AdminOrdersError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error, style: const TextStyle(fontFamily: 'Cairo')),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is AdminOrdersLoading || state is AdminOrdersInitial) {
              return Center(child: CircularProgressIndicator(color: brandOrange));
            }

            if (state is AdminOrdersLoaded) {
              final orders = state.orders.where((order) {
                return order.status != 'Delivered' && order.status != 'Cancelled';
              }).toList();

              if (orders.isEmpty) {
                return const Center(
                  child: Text(
                    'لا توجد طلبات جارية جديدة اليوم',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];

                  final List<String> validStatuses = [
                    'Pending',
                    'Processing',
                    'Waybill',
                    'Shipped',
                    'Delivered',
                    'Cancelled'
                  ];
                  final currentStatus = validStatuses.contains(order.status)
                      ? order.status
                      : 'Pending';

                  final String datePrefix =
                      '${order.date.year.toString().substring(2)}-${order.date.month.toString().padLeft(2, '0')}-${order.date.day.toString().padLeft(2, '0')}';

                  final String displayOrderNumber = order.orderNumber > 0
                      ? 'ORD-[$datePrefix]-${order.orderNumber}'
                      : 'ORD-${order.id.substring(0, order.id.length > 6 ? 6 : order.id.length).toUpperCase()}';

                  final String formattedDate =
                      '${order.date.day}/${order.date.month}/${order.date.year}';
                  final currentStatusConfig = _getStatusConfig(currentStatus);

                  String displayPaymentMethod = order.paymentMethod;
                  if (displayPaymentMethod.toLowerCase() == 'cash' ||
                      displayPaymentMethod == 'كاش') {
                    displayPaymentMethod = 'الدفع عند الاستلام';
                  }

                  String rawAddress = order.address;
                  String extractedName = '';

                  final RegExp regExp = RegExp(r'\(([^)]+)\)');
                  final match = regExp.firstMatch(rawAddress);
                  if (match != null && match.groupCount >= 1) {
                    String insideBracket = match.group(1)!;
                    if (insideBracket.contains('-')) {
                      extractedName = insideBracket.split('-')[0].trim();
                    } else {
                      extractedName = insideBracket.trim();
                    }
                  }

                  String cleanAddress = rawAddress.replaceAll(regExp, '').replaceAll('-', '').trim();
                  if (cleanAddress.isEmpty) {
                    cleanAddress = rawAddress;
                  }

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: brandOrange,
                        width: 1.5,
                      ),
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: primaryNavy,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: brandOrange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  displayPaymentMethod,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('orders').doc(order.id).get(),
                            builder: (context, snapshot) {
                              String customerName = extractedName;

                              if (snapshot.hasData && snapshot.data!.exists) {
                                var data = snapshot.data!.data() as Map<String, dynamic>;
                                if (customerName.isEmpty && data.containsKey('shippingAddress') && data['shippingAddress'] is Map) {
                                  var addr = data['shippingAddress'];
                                  customerName = '${addr['fullName'] ?? addr['firstName'] ?? ''} ${addr['lastName'] ?? ''}'.trim();
                                }
                                if (customerName.isEmpty) {
                                  customerName = (data['userName'] ?? data['customerName'] ?? data['name'] ?? '').toString().trim();
                                }
                              }
                              if (customerName.isEmpty) {
                                customerName = 'عميل أونلاين';
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline_rounded, size: 18, color: primaryNavy),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          customerName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: primaryNavy,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.phone_iphone_rounded, size: 18, color: primaryNavy),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          order.phone,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.location_on_outlined, size: 18, color: primaryNavy),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          cleanAddress,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                            height: 1.3,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7FB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المنتجات المطلوبة:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: primaryNavy,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...order.items.map(
                                      (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item.quantity}x ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: brandOrange,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${item.unitPrice} ج',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              children: [
                                Text(
                                  'الإجمالي: ${order.totalPrice.toStringAsFixed(2)} ج.م',
                                  style: TextStyle(
                                    color: brandOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: primaryNavy,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'تغيير الحالة:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              Flexible(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => _showStatusModal(
                                    context,
                                    order,
                                    currentStatus,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: currentStatusConfig['color'].withValues(alpha: 0.5),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      color: currentStatusConfig['color'].withValues(alpha: 0.1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            currentStatusConfig['text'],
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: currentStatusConfig['color'],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_down,
                                          color: currentStatusConfig['color'],
                                          size: 18,
                                        ),
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
      case 'Pending':
        return {'text': 'قيد الانتظار', 'color': Colors.orange};
      case 'Processing':
        return {'text': 'جاري التجهيز', 'color': Colors.blue};
      case 'Waybill':
        return {'text': 'بوليصة', 'color': Colors.cyan};
      case 'Shipped':
        return {'text': 'تم الشحن', 'color': Colors.deepPurple};
      case 'Delivered':
        return {'text': 'تم التوصيل', 'color': Colors.green};
      case 'Cancelled':
        return {'text': 'ملغي', 'color': Colors.red};
      default:
        return {'text': 'قيد الانتظار', 'color': Colors.orange};
    }
  }

  void _showStatusModal(
      BuildContext context,
      OrderModel order,
      String currentStatus,
      ) {
    final List<String> statuses = [
      'Pending',
      'Processing',
      'Waybill',
      'Shipped',
      'Delivered',
      'Cancelled'
    ];
    final adminOrdersCubit = context.read<AdminOrdersCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 20,
              left: 16,
              right: 16,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تحديث حالة الطلب',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...statuses.map((status) {
                    final config = _getStatusConfig(status);
                    final isSelected = currentStatus == status;

                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      tileColor: isSelected
                          ? config['color'].withValues(alpha: 0.1)
                          : Colors.transparent,
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: config['color'],
                      ),
                      title: Text(
                        config['text'],
                        style: TextStyle(
                          color: config['color'],
                          fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(bottomSheetContext);
                        if (!isSelected) {
                          adminOrdersCubit.updateStatus(order, status);
                          if (status == 'Delivered') {
                            await _automateLedgerEntry(order);
                          }
                          if (status == 'Delivered' || status == 'Cancelled') {
                            _showArchiveConfirmationDialog(status);
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