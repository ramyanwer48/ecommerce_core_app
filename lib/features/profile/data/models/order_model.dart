import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final double totalPrice;
  final String date;
  final String status;

  OrderModel({
    required this.id,
    required this.totalPrice,
    required this.date,
    required this.status,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json, String documentId) {
    // 1. معالجة التاريخ (تحويل Timestamp الخاص بفايربيز إلى نص مقروء)
    String formattedDate = 'تاريخ غير معروف';
    if (json['orderDate'] != null) {
      if (json['orderDate'] is Timestamp) {
        DateTime dt = (json['orderDate'] as Timestamp).toDate();
        // تنسيق التاريخ ليظهر هكذا: 2026/9/7
        formattedDate = '${dt.year}/${dt.month}/${dt.day}';
      } else {
        formattedDate = json['orderDate'].toString();
      }
    }

    return OrderModel(
      id: documentId,
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      date: formattedDate,
      status: json['status'] ?? 'Pending',
    );
  }
}