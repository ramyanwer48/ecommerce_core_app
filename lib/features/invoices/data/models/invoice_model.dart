import 'package:cloud_firestore/cloud_firestore.dart';

// --- دوال مساعدة (Helpers) للتحويل الآمن للبيانات ---
// هذه الدوال تمنع انهيار التطبيق إذا أرسل الذكاء الاصطناعي البيانات بصيغة مختلفة (نص بدلاً من رقم، أو نص بدلاً من Timestamp)

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is Timestamp) return value.toDate(); // في حالة القراءة من Firestore
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now(); // في حالة القراءة من الذكاء الاصطناعي
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}
// --------------------------------------------------

// 1. نموذج صنف الفاتورة (المنتج داخل الفاتورة)
class InvoiceItemModel {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;

  InvoiceItemModel({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  // حساب إجمالي بند الصنف
  double get totalItemPrice => unitPrice * quantity;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'unitPrice': unitPrice,
      'quantity': quantity,
    };
  }

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
      productId: map['productId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
      unitPrice: _parseDouble(map['unitPrice']),
      quantity: _parseInt(map['quantity']),
    );
  }
}

// 2. نموذج الفاتورة الرئيسية (رأس الفاتورة)
class InvoiceModel {
  final String id;
  final String invoiceNumber; // التسلسل الضريبي (مثال: INV-2026-1000)
  final String orderId;       // رقم الطلب المرتبط بالفاتورة
  final String partnerId;     // معرف العميل أو المورد
  final String partnerName;
  final String type;          // 'sale' أو 'purchase'
  final List<InvoiceItemModel> items;
  final double subtotal;      // الإجمالي قبل الخصم
  final double discountAmount;// قيمة الكوبون أو الخصم
  final double totalAmount;   // الصافي النهائي
  final DateTime date;
  final String status;        // 'paid' أو 'unpaid'

  InvoiceModel({
    required this.id,
    this.invoiceNumber = '',
    this.orderId = '',
    required this.partnerId,
    required this.partnerName,
    required this.type,
    required this.items,
    this.subtotal = 0.0,
    this.discountAmount = 0.0,
    required this.totalAmount,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber,
      'orderId': orderId,
      'partnerId': partnerId,
      'partnerName': partnerName,
      'type': type,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'date': Timestamp.fromDate(date),
      'status': status,
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map, String docId) {
    var rawItems = map['items'] as List<dynamic>? ?? [];
    List<InvoiceItemModel> parsedItems = rawItems
        .map((item) => InvoiceItemModel.fromMap(item as Map<String, dynamic>))
        .toList();

    return InvoiceModel(
      id: docId,
      invoiceNumber: map['invoiceNumber']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? '',
      partnerId: map['partnerId']?.toString() ?? '',
      partnerName: map['partnerName']?.toString() ?? '',
      type: map['type']?.toString() ?? 'sale',
      items: parsedItems,
      // استخدام دوال التحويل الآمنة لضمان عدم حدوث Crash
      subtotal: _parseDouble(map['subtotal'] ?? map['totalAmount']),
      discountAmount: _parseDouble(map['discountAmount']),
      totalAmount: _parseDouble(map['totalAmount']),
      date: _parseDate(map['date']),
      status: map['status']?.toString() ?? 'paid',
    );
  }
}