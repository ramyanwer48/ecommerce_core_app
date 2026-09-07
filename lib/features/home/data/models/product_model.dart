class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl; // الصورة الأساسية لشبكة المنتجات (للتوافق القديم)
  final List<String> images; // معرض الصور (Carousel)
  final List<String> variations; // خيارات الهاردوير (مثال: 16GB RAM / 32GB RAM)
  final String category;
  final bool inStock;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.images,
    required this.variations,
    required this.category,
    this.inStock = true,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json, String documentId) {
    // معالجة مصفوفة الصور بأمان
    List<String> parsedImages = [];
    if (json['images'] != null) {
      parsedImages = List<String>.from(json['images']);
    } else if (json['imageUrl'] != null && json['imageUrl'].toString().isNotEmpty) {
      // حماية للمنتجات القديمة: وضع الصورة الأساسية كصورة وحيدة في المعرض
      parsedImages = [json['imageUrl']];
    }

    // معالجة مصفوفة الخيارات بأمان
    List<String> parsedVariations = [];
    if (json['variations'] != null) {
      parsedVariations = List<String>.from(json['variations']);
    }

    return ProductModel(
      id: documentId,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      images: parsedImages,
      variations: parsedVariations,
      category: json['category'] ?? 'General',
      inStock: json['inStock'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'images': images,
      'variations': variations,
      'category': category,
      'inStock': inStock,
    };
  }
}