import 'package:flutter/material.dart';
import '../data/models/product_model.dart';
import '../../../core/di/dependency_injection.dart';
import '../../cart/logic/cart_cubit.dart';
class ProductDetailsScreen extends StatelessWidget {
  final ProductModel product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('تفاصيل المنتج', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000826), // لون متناسق مع Ramy Store
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. صورة المنتج الكبيرة
          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA), // لون خلفية هادئ للصورة
              image: product.imageUrl.isNotEmpty
                  ? DecorationImage(
                image: NetworkImage(product.imageUrl),
                fit: BoxFit.contain, // لجعل الصورة كاملة بدون قص
              )
                  : null,
            ),
            child: product.imageUrl.isEmpty
                ? const Icon(Icons.image_not_supported, size: 100, color: Colors.grey)
                : null,
          ),

          // 2. تفاصيل المنتج
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الاسم والسعر
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${product.price} ج.م',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF007BFF)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // حالة التوفر (في المخزن أم لا)
                  Row(
                    children: [
                      Icon(
                        product.inStock ? Icons.check_circle : Icons.cancel,
                        color: product.inStock ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        product.inStock ? 'متوفر في المخزن' : 'نفذت الكمية',
                        style: TextStyle(
                          color: product.inStock ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // الوصف
                  const Text(
                    'الوصف:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                  ),

                  const Spacer(),

                  // زر إضافة للسلة (Add to Cart)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        // إضافة المنتج للسلة المركزية
                        getIt<CartCubit>().addToCart(product);

                        // إظهار رسالة تأكيد احترافية
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم إضافة ${product.name} للسلة بنجاح!'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text(
                        'أضف للسلة',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}