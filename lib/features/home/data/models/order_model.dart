class OrderModel {
  final String orderId;
  final String userId; // معرّف العميل
  final List<String> productIds; // قائمة بأرقام المنتجات المطلوبة
  final double totalPrice; // السعر الإجمالي
  final DateTime orderDate; // وقت وتاريخ الطلب
  final String status; // حالة الطلب (قيد المراجعة، تم الشحن، مكتمل)

  OrderModel({
    required this.orderId,
    required this.userId,
    required this.productIds,
    required this.totalPrice,
    required this.orderDate,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'productIds': productIds,
      'totalPrice': totalPrice,
      'orderDate': orderDate.toIso8601String(),
      'status': status,
    };
  }
}