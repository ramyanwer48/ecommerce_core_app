import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addProduct({
    required String name,
    required double price,
    required String category,
    required String description,
    required String imageUrl,
    required bool inStock,
  }) async {
    // رفع المنتج بنفس المسميات الموجودة في صورتك تماماً
    await _firestore.collection('products').add({
      'name': name,
      'price': price,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'inStock': inStock,
    });
  }
}