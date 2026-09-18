import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItemModel {
  final String productId;
  final String name;
  final String imageUrl;
  final double unitPrice;
  final int quantity;
  final double totalCost;

  OrderItemModel({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.totalCost,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productId: json['productId'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      unitPrice: (json['unitPrice'] ?? json['price'] ?? 0.0).toDouble(),
      quantity: (json['quantity'] ?? 1).toInt(),
      totalCost: (json['totalCost'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'imageUrl': imageUrl,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'totalCost': totalCost,
    };
  }
}

class OrderModel {
  final String id; // معرف المستند في فايربيز
  final int orderNumber; // 👈 رقم مسلسل للطلب (مثل 1، 2، 3...)
  final String userId;
  final List<OrderItemModel> items; // 👈 تفاصيل المنتجات مش مجرد IDs
  final double totalPrice; // 👈 الإجمالي الحقيقي
  final String phone; // 👈 رقم الهاتف
  final String address; // 👈 العنوان بالتفصيل
  final String paymentMethod; // 👈 طريقة الدفع
  final DateTime orderDate;
  final String status;

  OrderModel({
    required this.id,
    this.orderNumber = 0,
    required this.userId,
    required this.items,
    required this.totalPrice,
    required this.phone,
    required this.address,
    required this.paymentMethod,
    required this.orderDate,
    required this.status,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json, String documentId) {
    // 🧠 معالجة قراءة العناصر بمرونة تامية
    var rawItems = json['items'] ?? json['cartItems'] ?? [];
    List<OrderItemModel> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 🧠 قراءة الإجمالي بأمان من أي اسم محتمل في فايربيز (totalPrice أو totalAmount)
    double resolvedTotal = 0.0;
    if (json['totalPrice'] != null) {
      resolvedTotal = (json['totalPrice'] as num).toDouble();
    } else if (json['totalAmount'] != null) {
      resolvedTotal = (json['totalAmount'] as num).toDouble();
    }

    // 🧠 قراءة العنوان ورقم الهاتف بمرونة من حقل مباشر أو من خريطة shippingAddress
    String resolvedPhone = json['phone'] ?? '';
    String resolvedAddress = json['address'] ?? '';

    if (json['shippingAddress'] is Map) {
      final shipping = json['shippingAddress'] as Map<String, dynamic>;
      if (resolvedPhone.isEmpty) resolvedPhone = shipping['phone'] ?? '';
      if (resolvedAddress.isEmpty) resolvedAddress = shipping['address'] ?? '';
    }

    // قراءة التاريخ بأمان (سواء كان Timestamp أو String)
    DateTime resolvedDate = DateTime.now();
    if (json['orderDate'] is Timestamp) {
      resolvedDate = (json['orderDate'] as Timestamp).toDate();
    } else if (json['createdAt'] is Timestamp) {
      resolvedDate = (json['createdAt'] as Timestamp).toDate();
    } else if (json['orderDate'] is String) {
      resolvedDate = DateTime.tryParse(json['orderDate']) ?? DateTime.now();
    }

    return OrderModel(
      id: documentId,
      orderNumber: (json['orderNumber'] ?? 0).toInt(),
      userId: json['userId'] ?? '',
      items: parsedItems,
      totalPrice: resolvedTotal,
      phone: resolvedPhone.isNotEmpty ? resolvedPhone : 'غير محدد',
      address: resolvedAddress.isNotEmpty ? resolvedAddress : 'غير محدد',
      paymentMethod: json['paymentMethod'] ?? 'Cash',
      orderDate: resolvedDate,
      status: json['status'] ?? 'Pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderNumber': orderNumber,
      'userId': userId,
      'items': items.map((i) => i.toJson()).toList(),
      'totalPrice': totalPrice,
      'phone': phone,
      'address': address,
      'paymentMethod': paymentMethod,
      'orderDate': Timestamp.fromDate(orderDate),
      'status': status,
    };
  }
}