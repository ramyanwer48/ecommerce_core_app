import 'package:cloud_firestore/cloud_firestore.dart';

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
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 0,
    );
  }
}

// 2. نموذج الفاتورة الرئيسية (رأس الفاتورة)
class InvoiceModel {
  final String id;
  final String invoiceNumber; // 👈 إضافة: التسلسل الضريبي (مثال: INV-2026-1000)
  final String orderId;       // 👈 إضافة: رقم الطلب المرتبط بالفاتورة
  final String partnerId;     // معرف العميل أو المورد
  final String partnerName;
  final String type;          // 'sale' أو 'purchase'
  final List<InvoiceItemModel> items;
  final double subtotal;      // 👈 إضافة: الإجمالي قبل الخصم
  final double discountAmount;// 👈 إضافة: قيمة الكوبون
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
      invoiceNumber: map['invoiceNumber'] ?? '',
      orderId: map['orderId'] ?? '',
      partnerId: map['partnerId'] ?? '',
      partnerName: map['partnerName'] ?? '',
      type: map['type'] ?? 'sale',
      items: parsedItems,
      // 👈 تم تأمين قراءة الحقول الجديدة مع التوافق مع البيانات القديمة لو وجدت
      subtotal: (map['subtotal'] ?? map['totalAmount'] ?? 0.0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0.0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'paid',
    );
  }
}