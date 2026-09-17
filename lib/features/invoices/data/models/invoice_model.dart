import 'package:cloud_firestore/cloud_firestore.dart';

// 1. نموذج صنف الفاتورة (المنتج داخل الفاتورة)
class InvoiceItemModel {
  final String productId;
  final String productName;
  final double unitPrice; // 👈 تجميد السعر: يتم حفظ السعر اللحظي هنا وقت البيع
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
  final String partnerId;     // معرف العميل (للمبيعات) أو المورد (للمشتريات)
  final String partnerName;
  final String type;          // نوع الفاتورة: 'sale' (مبيعات) أو 'purchase' (مشتريات)
  final List<InvoiceItemModel> items; // قائمة المنتجات المشتراة أو المباعة
  final double totalAmount;   // إجمالي الفاتورة النهائي
  final DateTime date;        // تاريخ وتوقت الإصدار
  final String status;        // حالة الدفع: 'paid' (مدفوعة) أو 'unpaid' (آجلة/على الحساب)

  InvoiceModel({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.type,
    required this.items,
    required this.totalAmount,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'partnerId': partnerId,
      'partnerName': partnerName,
      'type': type,
      'items': items.map((item) => item.toMap()).toList(),
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
      partnerId: map['partnerId'] ?? '',
      partnerName: map['partnerName'] ?? '',
      type: map['type'] ?? 'sale',
      items: parsedItems,
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'paid',
    );
  }
}