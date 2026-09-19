import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class ThermalPrinterService {
  // إنشاء نسخة (Instance) من مكتبة الطباعة
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  // 1. جلب قائمة الطابعات المقترنة (Bonded Devices) بموبايلك
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await bluetooth.getBondedDevices();
    } catch (e) {
      print("Error getting devices: $e");
      return [];
    }
  }

  // 2. الاتصال بالطابعة المختارة
  Future<void> connectToPrinter(BluetoothDevice device) async {
    try {
      await bluetooth.connect(device);
    } catch (e) {
      throw Exception("فشل الاتصال بالطابعة: $e");
    }
  }

  // 3. قطع الاتصال بالطابعة (مهم لتوفير البطارية ومنع التعليق)
  Future<void> disconnectPrinter() async {
    await bluetooth.disconnect();
  }

  // 4. تصميم الفاتورة / بوليصة الشحن وإرسالها للطابعة (محدثة لتوافق الحسابات والخصومات)
  Future<void> printOrderReceipt({
    required String orderNumber,               // 👈 تم التعديل إلى String لاستقبال التنسيق الجديد
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
    if (isConnected != true) {
      throw Exception("برجاء الاتصال بالطابعة أولاً من القائمة");
    }

    // تنسيق التاريخ بالتردد المحاسبي (يوم/شهر/سنة)
    String formattedDate = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

    bluetooth.printNewLine();
    bluetooth.printCustom("RAMY STORE - ERP", 3, 1); // اسم المتجر (حجم كبير، في المنتصف)
    bluetooth.printCustom("Official Receipt", 1, 1);
    bluetooth.printNewLine();

    bluetooth.printCustom("--------------------------------", 1, 1);
    // 👈 تم حذف علامة # ليطبع النص (ORD-...) بشكله الاحترافي كما هو
    bluetooth.printCustom("Order No: $orderNumber", 1, 0);
    bluetooth.printCustom("Date: $formattedDate", 1, 0);
    bluetooth.printCustom("Customer: $customerName", 1, 0);
    bluetooth.printCustom("Phone: $phone", 1, 0);
    bluetooth.printCustom("Address: $address", 1, 0);
    bluetooth.printCustom("Payment: $paymentMethod", 1, 0);
    bluetooth.printCustom("--------------------------------", 1, 1);

    // طباعة المنتجات
    bluetooth.printCustom("Products:", 1, 0);
    for (var item in products) {
      String name = item['name'].toString();
      String qty = item['quantity'].toString();
      double price = (item['unitPrice'] ?? item['price'] ?? 0.0).toDouble();

      // تقصير اسم المنتج لو طويل جداً على ورقة الطابعة (58mm)
      String shortName = name.length > 20 ? name.substring(0, 20) : name;

      // طباعة: (الكمية × اسم المنتج) على اليسار، و(السعر) على اليمين
      bluetooth.printLeftRight("$qty x $shortName", "${price.toStringAsFixed(2)} EGP", 1);
    }

    bluetooth.printCustom("--------------------------------", 1, 1);

    // الملخص المالي المطابق للقيود المحاسبية
    bluetooth.printLeftRight("Subtotal:", "${subtotal.toStringAsFixed(2)} EGP", 1);

    // طباعة سطر الخصم فقط لو كان هناك كوبون مستخدم بقيمة أكبر من صفر
    if (discountAmount > 0) {
      bluetooth.printLeftRight("Discount:", "-${discountAmount.toStringAsFixed(2)} EGP", 1);
    }

    bluetooth.printLeftRight("Final Total:", "${totalAmount.toStringAsFixed(2)} EGP", 1);

    bluetooth.printNewLine();
    bluetooth.printCustom("Thank You For Shopping!", 1, 1);
    bluetooth.printCustom("System Engineered by Ramy Anwar", 0, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();

    bluetooth.paperCut(); // أمر قص الورق التلقائي للطابعة
  }
}