import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String userId; // 👈 المتغير اللي كان ناقص عشان الإشعارات
  final double totalPrice;
  final String date;
  final String status;
  final String address;
  final String phone;

  OrderModel({
    required this.id,
    required this.userId, // 👈 إضافته هنا
    required this.totalPrice,
    required this.date,
    required this.status,
    required this.address,
    required this.phone,
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
      userId: json['userId'] ?? '', // 👈 سحب رقم العميل من قاعدة البيانات
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      date: formattedDate,
      status: json['status'] ?? 'Pending',
      address: json['address'] ?? 'غير محدد',
      phone: json['phone'] ?? 'غير محدد',
    );
  }
}