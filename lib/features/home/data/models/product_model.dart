import 'package:cloud_firestore/cloud_firestore.dart';

class MasterCatalogCategories {
  static const Map<String, List<String>> taxonomy = {
    'Computers & Systems': ['Desktops', 'Laptops', 'Servers & Workstations'],
    'PC Components': ['Processors / CPUs', 'Motherboards', 'Memory / RAM', 'Storage / HDD / SSD / NVMe', 'Graphics Cards / GPUs', 'Power Supplies / PSU', 'Computer Cases', 'Cooling Systems'],
    'Displays & Monitors': ['Standard Monitors', 'Gaming Monitors'],
    'Peripherals & Accessories': ['Keyboards', 'Mice & Pointers', 'Headsets & Audio', 'Webcams', 'Mousepads & Stands'],
    'Cables & Adapters': ['Video Cables', 'Data Cables', 'Power Cables', 'Adapters & Hubs'],
    'Laptop Specific Parts': ['Laptop Chargers', 'Laptop Batteries', 'Laptop Screens'],
    'Mobile Accessories': ['Mobile Chargers', 'Screen Protectors', 'Mobile Cases', 'Power Banks'],
    'Networking': ['Routers & Switches', 'Network Cables'],
    'Micro-Components & Maintenance': ['Sockets & Connectors', 'ICs & Chips', 'Jumpers & Screws', 'Thermal Paste & Cleaning'],
  };

  static List<String> get mainCategories => taxonomy.keys.toList();
  static List<String> getSubCategories(String mainCategory) => taxonomy[mainCategory] ?? [];
}

class ProductBatch {
  final String batchId;
  final int quantity;
  final double costPrice;
  final DateTime dateAdded;

  ProductBatch({required this.batchId, required this.quantity, required this.costPrice, required this.dateAdded});

  Map<String, dynamic> toJson() => {
    'batchId': batchId, 'quantity': quantity, 'costPrice': costPrice, 'dateAdded': Timestamp.fromDate(dateAdded),
  };

  factory ProductBatch.fromJson(Map<String, dynamic> json) => ProductBatch(
    batchId: json['batchId'] ?? '', quantity: json['quantity'] ?? 0, costPrice: (json['costPrice'] ?? json['sellingPrice'] ?? 0.0).toDouble(), dateAdded: (json['dateAdded'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final double oldPrice;
  final int salesCount;

  // 🚀 حقول التقييم الجديدة
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

  // 🚀 رجعتلك inStock كمتغير أساسي عشان الشاشات التانية متضربش إيرور
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
    this.rating = 0.0, this.reviewsCount = 0, // 👈 قيم اختيارية آمنة
    required this.imageUrl, required this.images, required this.variations, required this.category,
    this.subCategory = 'Uncategorized', this.barcodes = const [], this.unitOfMeasure = 'Piece', this.storageLocation = 'Main Storage',
    this.inStock = true, // 👈 رجعت للـ Constructor زي زمان
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
      parsedBatches = (json['batches'] as List).map((b) => ProductBatch.fromJson(b as Map<String, dynamic>)).toList();
      parsedBatches.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
    }

    double resolvedPrice = (json['price'] as num?)?.toDouble() ?? 0.0;
    double resolvedOldPrice = (json['oldPrice'] as num?)?.toDouble() ?? 0.0;
    int resolvedSalesCount = (json['salesCount'] as num?)?.toInt() ?? 0;

    double resolvedRating = (json['rating'] as num?)?.toDouble() ?? 0.0;
    int resolvedReviewsCount = (json['reviewsCount'] as num?)?.toInt() ?? 0;

    int resolvedStockQty = (json['stockQuantity'] as num?)?.toInt() ?? 0;

    // 💡 اللوجيك بيتحسب هنا بنظافة وبدون ما نبوظ الهيكلة
    int calculatedStock = parsedBatches.isNotEmpty ? parsedBatches.fold(0, (sum, b) => sum + b.quantity) : resolvedStockQty;
    bool resolvedInStock = (json['inStock'] == true) || calculatedStock > 0;

    return ProductModel(
      id: documentId,
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
      inStock: resolvedInStock, // 👈 بنبعت القيمة المحسوبة بأمان
      isActive: json['isActive'] ?? true,
      batches: parsedBatches,
      dbStockQuantity: resolvedStockQty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name, 'description': description, 'price': price,
      'oldPrice': oldPrice, 'salesCount': salesCount,
      'rating': rating, 'reviewsCount': reviewsCount,
      'imageUrl': imageUrl, 'imageUrls': images, 'images': images, 'variations': variations, 'category': category, 'subCategory': subCategory, 'barcodes': barcodes, 'unitOfMeasure': unitOfMeasure, 'storageLocation': storageLocation,
      'inStock': inStock,
      'isActive': isActive, 'stockQuantity': stockQuantity, 'batches': batches.map((b) => b.toJson()).toList(),
    };
  }
}