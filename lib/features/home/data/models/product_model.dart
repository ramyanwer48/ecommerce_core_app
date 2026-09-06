class ProductModel {
  final String id;
  final String name; // اسم القطعة (مثال: RTX 4090)
  final String description; // وصف القطعة
  final double price; // السعر
  final String imageUrl; // رابط صورة القطعة
  final int stockQuantity; // أهم متغير: الكمية المتاحة في المخزن
  final String category; // التصنيف (Laptops, GPUs, Accessories)

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.stockQuantity,
    required this.category,
  });

  // هذه الدالة ستقوم بتحويل البيانات القادمة من Firebase (Map) إلى كائن (Object) يفهمه Flutter
  factory ProductModel.fromJson(Map<String, dynamic> json, String documentId) {
    return ProductModel(
      id: documentId,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      // نحول السعر إلى double أياً كان نوعه في Firebase لتجنب الأخطاء
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      stockQuantity: json['stockQuantity'] ?? 0,
      category: json['category'] ?? '',
    );
  }

  // هذه الدالة ستحول بيانات التطبيق إلى شكل يقبله Firebase عند رفع منتج جديد للمخزن
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'stockQuantity': stockQuantity,
      'category': category,
    };
  }
}