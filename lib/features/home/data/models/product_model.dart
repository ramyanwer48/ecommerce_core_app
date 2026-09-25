import 'package:cloud_firestore/cloud_firestore.dart';

/// 🌳 شجرة التصنيفات المعتمدة للمتجر (Master Taxonomy)
class MasterCatalogCategories {
  static const Map<String, List<String>> taxonomy = {
    'Computers & Systems': [
      'Desktops',
      'Laptops',
      'Servers & Workstations'
    ],
    'PC Components': [
      'Processors / CPUs',
      'Motherboards',
      'Memory / RAM',
      'Storage / HDD / SSD / NVMe',
      'Graphics Cards / GPUs',
      'Power Supplies / PSU',
      'Computer Cases',
      'Cooling Systems'
    ],
    'Displays & Monitors': [
      'Standard Monitors',
      'Gaming Monitors'
    ],
    'Peripherals & Accessories': [
      'Keyboards',
      'Mice & Pointers',
      'Headsets & Audio',
      'Webcams',
      'Mousepads & Stands'
    ],
    'Cables & Adapters': [
      'Video Cables',
      'Data Cables',
      'Power Cables',
      'Adapters & Hubs'
    ],
    'Laptop Specific Parts': [
      'Laptop Chargers',
      'Laptop Batteries',
      'Laptop Screens'
    ],
    'Mobile Accessories': [
      'Mobile Chargers',
      'Screen Protectors',
      'Mobile Cases',
      'Power Banks'
    ],
    'Networking': [
      'Routers & Switches',
      'Network Cables'
    ],
    'Micro-Components & Maintenance': [
      'Sockets & Connectors',
      'ICs & Chips',
      'Jumpers & Screws',
      'Thermal Paste & Cleaning'
    ],
  };

  // قائمة مساعدة لجلب كل التصنيفات الرئيسية
  static List<String> get mainCategories => taxonomy.keys.toList();

  // دالة لجلب التصنيفات الفرعية بناءً على التصنيف الرئيسي
  static List<String> getSubCategories(String mainCategory) {
    return taxonomy[mainCategory] ?? [];
  }
}

class ProductBatch {
  final String batchId;
  final int quantity;
  final double costPrice; // سعر التكلفة (الشراء)
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
  final String name; // الاسم القياسي بالإنجليزية
  final String description;
  final double price; // سعر البيع للعميل
  final String imageUrl;
  final List<String> images;
  final List<String> variations;

  // 🏷️ الحقول الجديدة للمخازن والذكاء الاصطناعي
  final String category; // التصنيف الرئيسي
  final String subCategory; // التصنيف الفرعي (جديد)
  final List<String> barcodes; // لدعم باركودات متعددة للموردين (جديد)
  final String unitOfMeasure; // معامل القياس مثلاً: Piece, Box (جديد)
  final String storageLocation; // مكان الرف للبحث في الجرد (جديد)

  final bool inStock;
  final bool isActive;
  final List<ProductBatch> batches; // نظام الـ FIFO

  int get stockQuantity {
    if (batches.isEmpty) return 0;
    return batches.fold(0, (sum, batch) => sum + batch.quantity);
  }

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.images,
    required this.variations,
    required this.category,
    this.subCategory = 'Uncategorized', // قيمة افتراضية لتفادي أخطاء المنتجات القديمة
    this.barcodes = const [],
    this.unitOfMeasure = 'Piece',
    this.storageLocation = 'Main Storage',
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

    // 🏷️ استخراج الحقول الجديدة (الباركود) بأمان
    List<String> parsedBarcodes = [];
    if (json['barcodes'] != null) {
      parsedBarcodes = List<String>.from(json['barcodes']);
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
          costPrice: oldPrice * 0.7,
          dateAdded: DateTime.now().subtract(const Duration(days: 30)),
        ));
      }
    }

    double resolvedPrice = 0.0;
    if (json['price'] != null) {
      resolvedPrice = (json['price'] as num).toDouble();
    } else if (json['currentSalePrice'] != null) {
      resolvedPrice = (json['currentSalePrice'] as num).toDouble();
    } else if (parsedBatches.isNotEmpty) {
      resolvedPrice = parsedBatches.first.costPrice * 1.3;
    }

    return ProductModel(
      id: documentId,
      name: json['name'] ?? json['title'] ?? '',
      description: json['description'] ?? '',
      price: resolvedPrice,
      imageUrl: json['imageUrl'] ?? '',
      images: parsedImages,
      variations: parsedVariations,
      category: json['category'] ?? 'General',
      // 🏷️ قراءة الحقول الجديدة إن وجدت، أو وضع قيم افتراضية
      subCategory: json['subCategory'] ?? 'Uncategorized',
      barcodes: parsedBarcodes,
      unitOfMeasure: json['unitOfMeasure'] ?? 'Piece',
      storageLocation: json['storageLocation'] ?? 'Main Storage',
      inStock: json['inStock'] ?? true,
      isActive: json['isActive'] ?? true,
      batches: parsedBatches,
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
      // 🏷️ حفظ الحقول الجديدة في فايربيز
      'subCategory': subCategory,
      'barcodes': barcodes,
      'unitOfMeasure': unitOfMeasure,
      'storageLocation': storageLocation,
      'inStock': stockQuantity > 0,
      'isActive': isActive,
      'stockQuantity': stockQuantity,
      'batches': batches.map((b) => b.toJson()).toList(),
    };
  }
}