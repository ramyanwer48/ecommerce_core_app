import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class ThermalPrinterService {
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await bluetooth.getBondedDevices();
    } catch (e) {
      print("Error getting devices: $e");
      return [];
    }
  }

  Future<void> connectToPrinter(BluetoothDevice device) async {
    try {
      await bluetooth.connect(device);
    } catch (e) {
      throw Exception("فشل الاتصال بالطابعة: $e");
    }
  }

  Future<void> disconnectPrinter() async {
    await bluetooth.disconnect();
  }

  // 1. الفاتورة العادية
  Future<void> printOrderReceipt({
    required String orderNumber,
    required String customerName,
    required String phone,
    required String address,
    required double subtotal,
    required double discountAmount,
    required double totalAmount,
    required String paymentMethod,
    required List<Map<String, dynamic>> products,
  }) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected != true) throw Exception("برجاء الاتصال بالطابعة أولاً من القائمة");

    String formattedDate = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
    bluetooth.printNewLine();
    bluetooth.printCustom("RAMY STORE - ERP", 3, 1);
    bluetooth.printCustom("Official Receipt", 1, 1);
    bluetooth.printNewLine();
    bluetooth.printCustom("--------------------------------", 1, 1);
    bluetooth.printCustom("Order No: $orderNumber", 1, 0);
    bluetooth.printCustom("Date: $formattedDate", 1, 0);
    bluetooth.printCustom("Customer: $customerName", 1, 0);
    bluetooth.printCustom("Phone: $phone", 1, 0);
    bluetooth.printCustom("Address: $address", 1, 0);
    bluetooth.printCustom("Payment: $paymentMethod", 1, 0);
    bluetooth.printCustom("--------------------------------", 1, 1);

    bluetooth.printCustom("Products:", 1, 0);
    for (var item in products) {
      String name = item['name'].toString();
      String qty = item['quantity'].toString();
      double price = (item['unitPrice'] ?? item['price'] ?? 0.0).toDouble();
      String shortName = name.length > 20 ? name.substring(0, 20) : name;
      bluetooth.printLeftRight("$qty x $shortName", "${price.toStringAsFixed(2)} EGP", 1);
    }

    bluetooth.printCustom("--------------------------------", 1, 1);
    bluetooth.printLeftRight("Subtotal:", "${subtotal.toStringAsFixed(2)} EGP", 1);
    if (discountAmount > 0) bluetooth.printLeftRight("Discount:", "-${discountAmount.toStringAsFixed(2)} EGP", 1);
    bluetooth.printLeftRight("Final Total:", "${totalAmount.toStringAsFixed(2)} EGP", 1);
    bluetooth.printNewLine();
    bluetooth.printCustom("Thank You For Shopping!", 1, 1);
    bluetooth.printCustom("System Engineered by Ramy Anwar", 0, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  // 🚀 2. بوليصة الشحن (النسخة الاحترافية بالباركود ورقم التتبع الموحد)
  // 🚀 2. بوليصة الشحن (النسخة الاحترافية بالباركود والمنتجات)
  Future<void> printWaybill({
    required String orderNumber,
    required String customerName,
    required String phone,
    required String address,
    required double totalAmount,
    required String paymentMethod,
    required String courierName,
    required List<Map<String, dynamic>> products, // 👈 تم إضافة المنتجات هنا
  }) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected != true) throw Exception("برجاء الاتصال بالطابعة أولاً");

    String formattedDate = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

    bluetooth.printNewLine();
    bluetooth.printCustom("RAMY STORE - WAYBILL", 3, 1);
    bluetooth.printNewLine();

    // طباعة باركود (QR) ورقم التتبع
    bluetooth.printQRcode(orderNumber, 200, 200, 1);
    bluetooth.printCustom("TRACKING ID", 1, 1);
    bluetooth.printCustom(orderNumber, 2, 1);

    bluetooth.printCustom("--------------------------------", 1, 1);
    bluetooth.printCustom("Date: $formattedDate", 1, 0);
    bluetooth.printCustom("Courier: $courierName", 1, 0);
    bluetooth.printCustom("--------------------------------", 1, 1);

    bluetooth.printCustom("DELIVER TO:", 1, 0);
    bluetooth.printCustom("Name: $customerName", 1, 0);
    bluetooth.printCustom("Phone: $phone", 1, 0);
    bluetooth.printCustom("Address: $address", 1, 0);
    bluetooth.printCustom("--------------------------------", 1, 1);

    // 🌟 طباعة المنتجات (فاتورة مصغرة للمندوب والعميل)
    bluetooth.printCustom("Products:", 1, 0);
    for (var item in products) {
      String name = item['name'].toString();
      String qty = item['quantity'].toString();
      double price = (item['unitPrice'] ?? item['price'] ?? 0.0).toDouble();
      String shortName = name.length > 20 ? name.substring(0, 20) : name;
      bluetooth.printLeftRight("$qty x $shortName", "${price.toStringAsFixed(2)} EGP", 1);
    }
    bluetooth.printCustom("--------------------------------", 1, 1);

    // المبلغ المطلوب تحصيله
    String displayPayment = paymentMethod;
    if (displayPayment.toLowerCase() == 'cash' || displayPayment == 'كاش') {
      displayPayment = 'الدفع عند الاستلام';
    }

    bluetooth.printCustom("Payment: $displayPayment", 1, 0);
    if (displayPayment == 'الدفع عند الاستلام') {
      bluetooth.printLeftRight("COD AMOUNT:", "${totalAmount.toStringAsFixed(2)} EGP", 1);
    } else {
      bluetooth.printLeftRight("COD AMOUNT:", "PAID ONLINE", 1);
    }

    bluetooth.printNewLine();
    bluetooth.printCustom("System Engineered by Ramy Anwar", 0, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }
}