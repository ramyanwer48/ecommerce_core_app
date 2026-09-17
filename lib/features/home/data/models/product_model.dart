import 'package:cloud_firestore/cloud_firestore.dart';

class ProductBatch {
  final String batchId;
  final int quantity;
  final double costPrice; // سعر التكلفة (الشراء) عليك أنت كتاجر
  final DateTime dateAdded;

  ProductBatch({
    required this.batchId,
    required this.quantity,
    required this.costPrice,
    required this.dateAdded,
  });

  Map<String, dynamic> toJson() {
    return {
      'batchId': batchId,
      'quantity': quantity,
      'costPrice': costPrice,
      'dateAdded': Timestamp.fromDate(dateAdded),
    };
  }

  factory ProductBatch.fromJson(Map<String, dynamic> json) {
    return ProductBatch(
      batchId: json['batchId'] ?? '',
      quantity: json['quantity'] ?? 0,
      costPrice: (json['costPrice'] ?? json['sellingPrice'] ?? 0.0).toDouble(),
      dateAdded: (json['dateAdded'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price; // 👈 سعر البيع الموحد الثابت للعميل في الواجهة
  final String imageUrl;
  final List<String> images;
  final List<String> variations;
  final String category;
  final bool inStock;
  final bool isActive;
  final List<ProductBatch> batches;

  int get stockQuantity {
    if (batches.isEmpty) return 0;
    return batches.fold(0, (sum, batch) => sum + batch.quantity);
  }

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price, // 👈 أصبح مطلوباً بوضوح لضمان عدم ظهور السعر بصفر
    required this.imageUrl,
    required this.images,
    required this.variations,
    required this.category,
    this.inStock = true,
    this.isActive = true,
    required this.batches,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json, String documentId) {
    List<String> parsedImages = [];
    if (json['images'] != null) {
      parsedImages = List<String>.from(json['images']);
    } else if (json['imageUrl'] != null && json['imageUrl'].toString().isNotEmpty) {
      parsedImages = [json['imageUrl']];
    }

    List<String> parsedVariations = [];
    if (json['variations'] != null) {
      parsedVariations = List<String>.from(json['variations']);
    }

    List<ProductBatch> parsedBatches = [];
    if (json['batches'] != null) {
      parsedBatches = (json['batches'] as List)
          .map((b) => ProductBatch.fromJson(b as Map<String, dynamic>))
          .toList();
      parsedBatches.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
    } else {
      final int oldStock = json['stockQuantity'] != null ? (json['stockQuantity'] as num).toInt() : 0;
      final double oldPrice = (json['price'] ?? json['currentSalePrice'] ?? 0.0).toDouble();

      if (oldStock > 0 || oldPrice > 0) {
        parsedBatches.add(ProductBatch(
          batchId: 'legacy_batch_$documentId',
          quantity: oldStock,
          costPrice: oldPrice * 0.7, // تكلفة تقديرية للدفعة القديمة
          dateAdded: DateTime.now().subtract(const Duration(days: 30)),
        ));
      }
    }

    // 🧠 قراءة سعر البيع بأمان تام من أي حقل محتمل في فايربيز
    double resolvedPrice = 0.0;
    if (json['price'] != null) {
      resolvedPrice = (json['price'] as num).toDouble();
    } else if (json['currentSalePrice'] != null) {
      resolvedPrice = (json['currentSalePrice'] as num).toDouble();
    } else if (parsedBatches.isNotEmpty) {
      resolvedPrice = parsedBatches.first.costPrice * 1.3; // مرجع احتياطي لو السعر مش موجود
    }

    return ProductModel(
      id: documentId,
      name: json['name'] ?? json['title'] ?? '',
      description: json['description'] ?? '',
      price: resolvedPrice, // 👈 تعيين السعر الموحد الحقيقي
      imageUrl: json['imageUrl'] ?? '',
      images: parsedImages,
      variations: parsedVariations,
      category: json['category'] ?? 'General',
      inStock: json['inStock'] ?? true,
      isActive: json['isActive'] ?? true,
      batches: parsedBatches,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price, // 👈 حفظ سعر البيع الموحد في قاعدة البيانات
      'imageUrl': imageUrl,
      'images': images,
      'variations': variations,
      'category': category,
      'inStock': stockQuantity > 0,
      'isActive': isActive,
      'stockQuantity': stockQuantity,
      'batches': batches.map((b) => b.toJson()).toList(),
    };
  }
}