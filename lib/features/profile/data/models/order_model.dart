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
  final String id;
  final int orderNumber;
  final String userId;
  final List<OrderItemModel> items;
  final double totalPrice;
  final String phone;
  final String address;
  final String paymentMethod;
  final DateTime orderDate;
  final String status;
// 👈 ممر سحري عشان لو أي شاشة بتنادي على .date تشتغل معاك عادي
  DateTime get date => orderDate;
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
    var rawItems = json['items'] ?? json['cartItems'] ?? [];
    List<OrderItemModel> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    double resolvedTotal = 0.0;
    if (json['totalPrice'] != null) {
      resolvedTotal = (json['totalPrice'] as num).toDouble();
    } else if (json['totalAmount'] != null) {
      resolvedTotal = (json['totalAmount'] as num).toDouble();
    }

    String resolvedPhone = json['phone'] ?? '';
    String resolvedAddress = json['address'] ?? '';

    if (json['shippingAddress'] is Map) {
      final shipping = json['shippingAddress'] as Map<String, dynamic>;
      if (resolvedPhone.isEmpty) resolvedPhone = shipping['phone'] ?? '';
      if (resolvedAddress.isEmpty) resolvedAddress = shipping['address'] ?? '';
    }

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