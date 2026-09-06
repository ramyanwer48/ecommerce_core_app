class ProductModel {
  final String id; // معرف فريد للمنتج (Document ID في Firestore)
  final String name; // اسم المنتج (مثلاً: ASUS ROG Laptop)
  final String description; // وصف المنتج
  final double price; // السعر
  final String imageUrl; // رابط صورة المنتج
  final String category; // الفئة (مثلاً: Laptops, GPUs)
  final bool inStock; // هل متوفر في المخزن؟

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.inStock = true,
  });

  // دالة لتحويل بيانات Firestore (JSON) إلى كائن (Object) داخل فلاتر
  factory ProductModel.fromJson(Map<String, dynamic> json, String documentId) {
    return ProductModel(
      id: documentId,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      category: json['category'] ?? 'General',
      inStock: json['inStock'] ?? true,
    );
  }

  // دالة لتحويل بيانات الكائن (Object) إلى JSON لإرساله إلى Firestore
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'inStock': inStock,
    };
  }
}