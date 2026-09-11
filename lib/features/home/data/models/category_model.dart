class CategoryModel {
  final String id;
  final String name;
  final String imageUrl; // صورة أو أيقونة القسم
  final bool isActive;   // عشان لو حبيت توقف قسم مؤقتاً (زي قسم عروض العيد)
  final int orderIndex;  // عشان ترتب الأقسام بمزاجك (مين يظهر الأول)

  CategoryModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.isActive = true,
    this.orderIndex = 0,
  });

  // تحويل الداتا اللي جاية من الفايربيز إلى موديل
  factory CategoryModel.fromJson(Map<String, dynamic> json, String documentId) {
    return CategoryModel(
      id: documentId,
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      isActive: json['isActive'] ?? true,
      orderIndex: json['orderIndex'] ?? 0,
    );
  }

  // تحويل الموديل لـ Map عشان نرفعه للفايربيز
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'orderIndex': orderIndex,
    };
  }
}