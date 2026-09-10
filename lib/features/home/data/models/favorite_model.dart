// lib/features/home/data/models/favorite_model.dart
class FavoriteModel {
  final String productId;
  final String name;
  final double price;
  final String imageUrl;
  final bool isActive; // 👈 المتغير الجديد

  FavoriteModel({
    required this.productId,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.isActive = true, // 👈 الافتراضي true للحماية
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json, String id) {
    return FavoriteModel(
      productId: id,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      isActive: json['isActive'] ?? true, // 👈 قراءة الحالة
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'isActive': isActive, // 👈 حفظ الحالة
    };
  }
}