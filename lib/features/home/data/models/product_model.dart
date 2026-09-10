class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final List<String> images;
  final List<String> variations;
  final String category;
  final bool inStock;
  final bool isActive; // 👈 المتغير الجديد (True = المنتج يظهر في المتجر، False = المنتج محذوف ومخفي)

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
    this.isActive = true, // 👈 القيمة الافتراضية لأي منتج جديد إنه شغال ومتاح
  });

  factory ProductModel.fromJson(Map<String, dynamic> json, String documentId) {
    // معالجة مصفوفة الصور بأمان
    List<String> parsedImages = [];
    if (json['images'] != null) {
      parsedImages = List<String>.from(json['images']);
    } else if (json['imageUrl'] != null && json['imageUrl'].toString().isNotEmpty) {
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
      isActive: json['isActive'] ?? true, // 👈 قراءة حالة المنتج (لو مش موجودة في منتج قديم هتعتبر true أوتوماتيك)
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
      'isActive': isActive, // 👈 حفظ الحالة الجديدة في الفايربيز
    };
  }
}