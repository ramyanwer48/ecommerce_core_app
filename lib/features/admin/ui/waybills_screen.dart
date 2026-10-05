import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../../core/services/thermal_printer_service.dart';

class WaybillsScreen extends StatefulWidget {
  const WaybillsScreen({super.key});

  @override
  State<WaybillsScreen> createState() => _WaybillsScreenState();
}

class _WaybillsScreenState extends State<WaybillsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ThermalPrinterService _printerService = ThermalPrinterService();
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  // 🚀 الدالة الذكية (المحدثة): تستخرج الاسم وتقوم بتنظيف العنوان من الأقواس المزعجة
  Map<String, String> _extractAndCleanCustomerData(Map<String, dynamic> data) {
    String customerName = '';
    String addressStr = (data['address'] ?? '').toString();

    // 1. محاولة استخراج الاسم من الحقول المباشرة
    customerName = (data['customerName'] ?? data['userName'] ?? data['name'] ?? '').toString().trim();

    if (customerName.isEmpty && data.containsKey('shippingAddress') && data['shippingAddress'] is Map) {
      var addr = data['shippingAddress'];
      customerName = '${addr['firstName'] ?? ''} ${addr['lastName'] ?? ''}'.trim();
    }

    // 2. إذا لم نجد الاسم، أو كان العنوان يحتوي على أقواس (مثل الداتا القديمة)
    if (addressStr.contains('(') && addressStr.contains(')')) {
      int startIndex = addressStr.indexOf('(') + 1;
      int endIndex = addressStr.indexOf(')');

      if (startIndex < endIndex) {
        String insideParentheses = addressStr.substring(startIndex, endIndex);

        // استخراج الاسم
        if (customerName.isEmpty || customerName == 'عميل أونلاين') {
          if (insideParentheses.contains('-')) {
            customerName = insideParentheses.split('-')[0].trim();
          } else {
            customerName = insideParentheses.trim();
          }
        }

        // 🚀 تنظيف العنوان: إزالة كل ما بين الأقواس والأقواس نفسها
        addressStr = addressStr.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
      }
    }

    if (customerName.isEmpty) customerName = 'عميل أونلاين';

    return {
      'name': customerName,
      'address': addressStr,
    };
  }

  void _showConnectPrinterSheet() {
    List<BluetoothDevice> devices = [];
    bool isLoading = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
          builder: (context, setSheetState) {
            if (isLoading && devices.isEmpty) {
              _printerService.getBondedDevices().then((fetchedDevices) {
                if (mounted) {
                  setSheetState(() {
                    devices = fetchedDevices;
                    isLoading = false;
                  });
                }
              });
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 16),
                    const Text('الاتصال بطابعة بوالص الشحن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    const SizedBox(height: 20),

                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (devices.isEmpty)
                      const Text('لم يتم العثور على طابعات بلوتوث مقترنة.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.print, color: Colors.white)),
                            title: Text(device.name ?? 'طابعة', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(device.address ?? ''),
                            onTap: () async {
                              try {
                                await _printerService.connectToPrinter(device);
                                Navigator.pop(sheetCtx);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاتصال بالطابعة بنجاح 🖨️', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الاتصال: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                              }
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          }
      ),
    );
  }

  void _showWaybillPreview(Map<String, dynamic> orderData, String orderId, String unifiedOrderNumber) {
    List<dynamic> items = orderData['items'] ?? [];
    double total = (orderData['totalPrice'] ?? 0).toDouble();
    String paymentMethod = orderData['paymentMethod'] ?? 'كاش';
    if (paymentMethod.toLowerCase() == 'cash' || paymentMethod == 'كاش') {
      paymentMethod = 'الدفع عند الاستلام';
    }

    // 👈 استدعاء البيانات المنظفة (الاسم والعنوان)
    Map<String, String> cleanData = _extractAndCleanCustomerData(orderData);
    String correctCustomerName = cleanData['name'] ?? 'عميل أونلاين';
    String cleanAddress = cleanData['address'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('معاينة بوليصة الشحن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
                  const Divider(thickness: 2),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Icon(Icons.qr_code_2, size: 60, color: Colors.grey.shade800)),
                        Center(child: Text(unifiedOrderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        const SizedBox(height: 8),
                        const Text('بيانات العميل:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('الاسم: $correctCustomerName', style: const TextStyle(fontSize: 12)),
                        Text('الهاتف: ${orderData['phone'] ?? ''}', style: const TextStyle(fontSize: 12)),
                        Text('العنوان: $cleanAddress', style: const TextStyle(fontSize: 12)), // 👈 العنوان المنظف
                        const Divider(),
                        const Text('المنتجات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ...items.map((item) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('${item['quantity']} x ${item['name']}', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            Text('${item['unitPrice']} ج', style: const TextStyle(fontSize: 11)),
                          ],
                        )),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('المطلوب تحصيله:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(paymentMethod == 'الدفع عند الاستلام' ? '$total ج.م' : 'مدفوع أونلاين', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryNavy),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAssignCourierSheet(orderData, orderId, unifiedOrderNumber);
                          },
                          icon: const Icon(Icons.print, size: 18, color: Colors.white),
                          label: const Text('اختيار المندوب وطباعة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white)),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignCourierSheet(Map<String, dynamic> orderData, String orderId, String unifiedOrderNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.only(top: 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              const Text('تسليم الأوردر لمندوب الشحن', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('couriers').where('isActive', isEqualTo: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد شركات شحن نشطة.', style: TextStyle(fontFamily: 'Cairo')));

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var courier = snapshot.data!.docs[index];
                        String courierName = courier['name'] ?? 'غير معروف';

                        return ListTile(
                          leading: CircleAvatar(backgroundColor: brandOrange.withOpacity(0.1), child: Icon(Icons.local_shipping, color: brandOrange)),
                          title: Text(courierName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.print, color: Colors.grey),
                          onTap: () async {
                            Navigator.pop(ctx);
                            _assignAndPrint(orderData, orderId, unifiedOrderNumber, courier.id, courierName);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _assignAndPrint(Map<String, dynamic> orderData, String orderId, String unifiedOrderNumber, String courierId, String courierName) async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));

    try {
      List<Map<String, dynamic>> productsList = [];
      if (orderData['items'] != null) {
        for (var item in orderData['items']) {
          productsList.add({
            'name': item['name'] ?? 'منتج غير معروف',
            'quantity': item['quantity'] ?? 1,
            'unitPrice': item['unitPrice'] ?? item['price'] ?? 0.0,
          });
        }
      }

      Map<String, String> cleanData = _extractAndCleanCustomerData(orderData);

      await _printerService.printWaybill(
        orderNumber: unifiedOrderNumber,
        customerName: cleanData['name'] ?? 'عميل',
        phone: orderData['phone'] ?? '',
        address: cleanData['address'] ?? '', // 👈 تمرير العنوان المنظف للطباعة الحرارية
        totalAmount: (orderData['totalPrice'] ?? 0.0).toDouble(),
        paymentMethod: orderData['paymentMethod'] ?? 'Cash',
        courierName: courierName,
        products: productsList,
      );

      await _firestore.collection('orders').doc(orderId).update({
        'status': 'Shipped',
        'courierId': courierId,
        'courierName': courierName,
        'shippedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إسناد الطلب للمندوب وطباعة البوليصة بنجاح 🚀', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تأكد من الاتصال بالطابعة أولاً', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('إصدار بوالص الشحن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.white),
              onPressed: _showConnectPrinterSheet,
            )
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('orders').where('status', isEqualTo: 'Processing').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 60, color: Colors.green.shade300),
                    const SizedBox(height: 12),
                    const Text('لا توجد طلبات معتمدة بانتظار التجهيز.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 16)),
                  ],
                ),
              );
            }

            var orders = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                var orderDoc = orders[index];
                var data = orderDoc.data() as Map<String, dynamic>;

                int orderNumberInt = data['orderNumber'] ?? 0;
                Timestamp? dateTs = data['date'];
                DateTime date = dateTs != null ? dateTs.toDate() : DateTime.now();
                String datePrefix = '${date.year.toString().substring(2)}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

                String unifiedOrderNumber = orderNumberInt > 0
                    ? 'ORD-$datePrefix-$orderNumberInt'
                    : 'ORD-${orderDoc.id.substring(0, orderDoc.id.length > 6 ? 6 : orderDoc.id.length).toUpperCase()}';

                Map<String, String> cleanData = _extractAndCleanCustomerData(data);
                double total = (data['totalPrice'] ?? 0).toDouble();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(backgroundColor: brandOrange.withOpacity(0.1), child: Icon(Icons.qr_code_scanner, color: brandOrange)),
                    title: Text(unifiedOrderNumber, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    subtitle: Text('العميل: ${cleanData['name']}\nالإجمالي: $total ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, height: 1.5)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () => _showWaybillPreview(data, orderDoc.id, unifiedOrderNumber),
                      child: const Text('معاينة وطباعة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}