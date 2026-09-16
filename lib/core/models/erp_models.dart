import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------
// 1. نموذج الأطراف (العملاء، الموردين، الشركاء، شركات الشحن)
// ---------------------------------------------------------
class PartnerModel {
  final String id;
  final String name;
  final String type; // 'customer', 'supplier', 'partner', 'shipping'
  final String phone;

  PartnerModel({
    required this.id,
    required this.name,
    required this.type,
    required this.phone,
  });

  factory PartnerModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PartnerModel(
      id: documentId,
      name: map['name'] ?? '',
      type: map['type'] ?? 'customer',
      phone: map['phone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'phone': phone,
    };
  }
}

// ---------------------------------------------------------
// 2. نموذج المنتجات (يحتوي على السعر الحالي)
// ---------------------------------------------------------
class ProductModel {
  final String id;
  final String name;
  final double currentSalePrice;
  final double currentCostPrice;
  final int stockQuantity;

  ProductModel({
    required this.id,
    required this.name,
    required this.currentSalePrice,
    required this.currentCostPrice,
    required this.stockQuantity,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ProductModel(
      id: documentId,
      name: map['name'] ?? '',
      currentSalePrice: (map['currentSalePrice'] ?? 0.0).toDouble(),
      currentCostPrice: (map['currentCostPrice'] ?? 0.0).toDouble(),
      stockQuantity: map['stockQuantity'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'currentSalePrice': currentSalePrice,
      'currentCostPrice': currentCostPrice,
      'stockQuantity': stockQuantity,
    };
  }
}

// ---------------------------------------------------------
// 3. نموذج الفاتورة (وهنا سر "تجميد الأسعار" Snapshot)
// ---------------------------------------------------------
class InvoiceItemModel {
  final String productId;
  final String name;
  final int qty;
  final double snapshotSalePrice; // السعر المجمد وقت البيع
  final double snapshotCostPrice; // التكلفة المجمدة وقت الشراء

  InvoiceItemModel({
    required this.productId,
    required this.name,
    required this.qty,
    required this.snapshotSalePrice,
    required this.snapshotCostPrice,
  });

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      qty: map['qty'] ?? 0,
      snapshotSalePrice: (map['snapshotSalePrice'] ?? 0.0).toDouble(),
      snapshotCostPrice: (map['snapshotCostPrice'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'qty': qty,
      'snapshotSalePrice': snapshotSalePrice,
      'snapshotCostPrice': snapshotCostPrice,
    };
  }
}

class InvoiceModel {
  final String id;
  final String type; // 'sale', 'purchase', 'return'
  final String status; // 'draft', 'approved'
  final String partnerId;
  final List<InvoiceItemModel> items;
  final double totalAmount;
  final DateTime createdAt;

  InvoiceModel({
    required this.id,
    required this.type,
    required this.status,
    required this.partnerId,
    required this.items,
    required this.totalAmount,
    required this.createdAt,
  });

  factory InvoiceModel.fromMap(Map<String, dynamic> map, String documentId) {
    return InvoiceModel(
      id: documentId,
      type: map['type'] ?? 'sale',
      status: map['status'] ?? 'draft',
      partnerId: map['partnerId'] ?? '',
      items: List<InvoiceItemModel>.from(
        (map['items'] as List? ?? []).map((x) => InvoiceItemModel.fromMap(x)),
      ),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'status': status,
      'partnerId': partnerId,
      'items': items.map((x) => x.toMap()).toList(),
      'totalAmount': totalAmount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// ---------------------------------------------------------
// 4. نموذج القيود المحاسبية (دفتر الأستاذ للـ Double-Entry)
// ---------------------------------------------------------
class LedgerEntryModel {
  final String id;
  final String accountId; // رقم حساب المورد/العميل أو الخزينة
  final double debit; // مدين (عليه)
  final double credit; // دائن (له)
  final String referenceId; // رقم الفاتورة أو الحركة
  final String description;
  final DateTime timestamp;

  LedgerEntryModel({
    required this.id,
    required this.accountId,
    required this.debit,
    required this.credit,
    required this.referenceId,
    required this.description,
    required this.timestamp,
  });

  factory LedgerEntryModel.fromMap(Map<String, dynamic> map, String documentId) {
    return LedgerEntryModel(
      id: documentId,
      accountId: map['accountId'] ?? '',
      debit: (map['debit'] ?? 0.0).toDouble(),
      credit: (map['credit'] ?? 0.0).toDouble(),
      referenceId: map['referenceId'] ?? '',
      description: map['description'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'debit': debit,
      'credit': credit,
      'referenceId': referenceId,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}