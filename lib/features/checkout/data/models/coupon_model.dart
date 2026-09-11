class CouponModel {
  final String id;
  final String code;
  final double discountPercentage; // نسبة الخصم (مثلاً 10 يعني 10%)
  final bool isActive;

  CouponModel({
    required this.id,
    required this.code,
    required this.discountPercentage,
    required this.isActive,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json, String id) {
    return CouponModel(
      id: id,
      code: json['code'] ?? '',
      discountPercentage: (json['discountPercentage'] ?? 0).toDouble(),
      isActive: json['isActive'] ?? false,
    );
  }
}