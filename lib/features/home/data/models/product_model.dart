import 'package:cloud_firestore/cloud_firestore.dart';

class ProductBatch {
  final String batchId;
  final int quantity;
  final double costPrice;
  final DateTime dateAdded;

  ProductBatch({required this.batchId, required this.quantity, required this.costPrice, required this.dateAdded});

  Map<String, dynamic> toJson() => {
    'batchId': batchId,
    'quantity': quantity,
    'costPrice': costPrice,
    'dateAdded': dateAdded.toIso8601String(),
  };

  factory ProductBatch.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate = DateTime.now();
    if (json['dateAdded'] is Timestamp) {
      parsedDate = (json['dateAdded'] as Timestamp).toDate();
    } else if (json['dateAdded'] is String) {
      parsedDate = DateTime.tryParse(json['dateAdded']) ?? DateTime.now();
    }

    return ProductBatch(
      batchId: json['batchId']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      dateAdded: parsedDate,
    );
  }
}

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final double oldPrice;
  final int salesCount;
  final double rating;
  final int reviewsCount;
  final String imageUrl;
  final List<String> images;
  final List<String> variations;
  final String category;
  final String subCategory;
  final List<String> barcodes;
  final String unitOfMeasure;
  final String storageLocation;
  final bool inStock;
  final bool isActive;
  final List<ProductBatch> batches;
  final int _dbStockQuantity;

  int get stockQuantity {
    if (batches.isNotEmpty) {
      return batches.fold(0, (sum, batch) => sum + batch.quantity);
    }
    return _dbStockQuantity;
  }

  ProductModel({
    required this.id, required this.name, required this.description, required this.price,
    this.oldPrice = 0.0, this.salesCount = 0,
    this.rating = 0.0, this.reviewsCount = 0,
    required this.imageUrl, required this.images, required this.variations, required this.category,
    this.subCategory = 'Uncategorized', this.barcodes = const [], this.unitOfMeasure = 'Piece', this.storageLocation = 'Main Storage',
    this.inStock = true,
    this.isActive = true, required this.batches,
    int dbStockQuantity = 0,
  }) : _dbStockQuantity = dbStockQuantity;

  factory ProductModel.fromJson(Map<String, dynamic> json, String documentId) {
    List<String> parsedImages = [];
    if (json['imageUrls'] != null) {
      parsedImages = List<String>.from(json['imageUrls']);
    } else if (json['images'] != null) {
      parsedImages = List<String>.from(json['images']);
    } else if (json['imageUrl'] != null && json['imageUrl'].toString().isNotEmpty) {
      parsedImages = [json['imageUrl']];
    }

    List<String> parsedVariations = [];
    if (json['variations'] != null) parsedVariations = List<String>.from(json['variations']);

    List<String> parsedBarcodes = [];
    if (json['barcodes'] != null) parsedBarcodes = List<String>.from(json['barcodes']);

    List<ProductBatch> parsedBatches = [];
    if (json['batches'] != null) {
      parsedBatches = (json['batches'] as List).map((b) => ProductBatch.fromJson(Map<String, dynamic>.from(b as Map))).toList();
      parsedBatches.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
    }

    double resolvedPrice = (json['price'] as num?)?.toDouble() ?? 0.0;
    double resolvedOldPrice = (json['oldPrice'] as num?)?.toDouble() ?? 0.0;
    int resolvedSalesCount = (json['salesCount'] as num?)?.toInt() ?? 0;

    double resolvedRating = (json['rating'] as num?)?.toDouble() ?? 0.0;
    int resolvedReviewsCount = (json['reviewsCount'] as num?)?.toInt() ?? 0;

    int resolvedStockQty = (json['stockQuantity'] as num?)?.toInt() ?? 0;

    int calculatedStock = parsedBatches.isNotEmpty ? parsedBatches.fold(0, (sum, b) => sum + b.quantity) : resolvedStockQty;
    bool resolvedInStock = (json['inStock'] == true) || calculatedStock > 0;

    String resolvedId = documentId.isNotEmpty ? documentId : (json['id']?.toString() ?? '');

    return ProductModel(
      id: resolvedId,
      name: json['name'] ?? json['title'] ?? '',
      description: json['description'] ?? '',
      price: resolvedPrice,
      oldPrice: resolvedOldPrice,
      salesCount: resolvedSalesCount,
      rating: resolvedRating,
      reviewsCount: resolvedReviewsCount,
      imageUrl: json['imageUrl'] ?? '',
      images: parsedImages,
      variations: parsedVariations,
      category: json['category'] ?? 'General',
      subCategory: json['subCategory'] ?? 'Uncategorized',
      barcodes: parsedBarcodes,
      unitOfMeasure: json['unitOfMeasure'] ?? 'Piece',
      storageLocation: json['storageLocation'] ?? 'Main Storage',
      inStock: resolvedInStock,
      isActive: json['isActive'] ?? true,
      batches: parsedBatches,
      dbStockQuantity: resolvedStockQty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name, 'description': description, 'price': price,
      'oldPrice': oldPrice, 'salesCount': salesCount,
      'rating': rating, 'reviewsCount': reviewsCount,
      'imageUrl': imageUrl, 'imageUrls': images, 'images': images, 'variations': variations, 'category': category, 'subCategory': subCategory, 'barcodes': barcodes, 'unitOfMeasure': unitOfMeasure, 'storageLocation': storageLocation,
      'inStock': inStock,
      'isActive': isActive, 'stockQuantity': stockQuantity, 'batches': batches.map((b) => b.toJson()).toList(),
    };
  }
}