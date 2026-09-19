import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../services/thermal_printer_service.dart';

void showPrinterBottomSheet({
  required BuildContext context,
  required String orderNumber,               // 👈 تم التعديل إلى String
  required String customerName,
  required String phone,
  required String address,
  required double subtotal,
  required double discountAmount,
  required double totalAmount,
  required String paymentMethod,
  required List<Map<String, dynamic>> products,
}) {
  // ... (باقي الكود كما هو)
  final printerService = ThermalPrinterService();
  List<BluetoothDevice> devices = [];
  bool isLoading = true;
  String? connectingDeviceAddress; // حل مشكلة اللودينج (حفظ عنوان الجهاز الجاري الاتصال به فقط)

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          if (isLoading && devices.isEmpty) {
            printerService.getBondedDevices().then((fetchedDevices) {
              setState(() {
                devices = fetchedDevices;
                isLoading = false;
              });
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
                  const Text('اختر طابعة الفواتير (Bluetooth)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  const SizedBox(height: 20),

                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (devices.isEmpty)
                    const Text('لم يتم العثور على طابعات مقترنة.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: devices.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        bool isThisDeviceConnecting = connectingDeviceAddress == device.address;

                        return ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.print_rounded, color: Colors.blue)),
                          title: Text(device.name ?? 'طابعة غير معروفة', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(device.address ?? ''),
                          trailing: isThisDeviceConnecting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.bluetooth_connected, color: Colors.green),
                          // منع الضغط على أي جهاز آخر أثناء الاتصال
                          onTap: connectingDeviceAddress != null ? null : () async {
                            setState(() { connectingDeviceAddress = device.address; });
                            try {
                              await printerService.connectToPrinter(device);

                              // 👈 تمرير البيانات المالية المحدثة لدالة الطباعة
                              await printerService.printOrderReceipt(
                                orderNumber: orderNumber,
                                customerName: customerName,
                                phone: phone,
                                address: address,
                                subtotal: subtotal,
                                discountAmount: discountAmount,
                                totalAmount: totalAmount,
                                paymentMethod: paymentMethod,
                                products: products,
                              );

                              await printerService.disconnectPrinter();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الطباعة بنجاح! 🖨️'), backgroundColor: Colors.green));
                              Navigator.pop(sheetContext);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}'), backgroundColor: Colors.red));
                            } finally {
                              setState(() { connectingDeviceAddress = null; });
                            }
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}