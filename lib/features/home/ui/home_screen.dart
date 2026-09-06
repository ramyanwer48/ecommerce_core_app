import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/home_cubit.dart';
import '../logic/home_state.dart';
import '../data/models/product_model.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // لون خلفية هادئ ومريح للعين
      appBar: AppBar(
        title: const Text('RAMY STORE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              // توجيه المستخدم لشاشة السلة
              context.push(Routes.cart);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          // 1. حالة التحميل
          if (state is HomeLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)));
          }
          // 2. حالة حدوث خطأ
          else if (state is HomeError) {
            return Center(
              child: Text('حدث خطأ: ${state.message}', style: const TextStyle(color: Colors.red, fontSize: 16)),
            );
          }
          // 3. حالة نجاح جلب البيانات
          else if (state is HomeLoaded) {
            final products = state.products;

            // إذا كانت قاعدة البيانات فارغة
            if (products.isEmpty) {
              return const Center(
                child: Text('المتجر فارغ حالياً. قم بإضافة منتجات من Firebase!',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
              );
            }

            // عرض المنتجات في شبكة (Grid)
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // عدد الأعمدة (منتجين بجوار بعض)
                childAspectRatio: 0.68, // نسبة الطول للعرض للكارت
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return _buildProductCard(context, products[index]); // أضفنا context هنا
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // تصميم كارت المنتج
  // تصميم كارت المنتج مع تفعيل الضغط
  Widget _buildProductCard(BuildContext context, ProductModel product) { // أضفنا BuildContext هنا
    return GestureDetector(
      onTap: () {
        // الانتقال لشاشة التفاصيل مع تمرير بيانات المنتج (product) كـ extra
        context.push(Routes.productDetails, extra: product);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: product.imageUrl.isNotEmpty
                    ? Image.network(product.imageUrl, fit: BoxFit.cover, width: double.infinity)
                    : Container(color: Colors.grey[200], child: const Icon(Icons.image, size: 50, color: Colors.grey)),
              ),
            ),
            // تفاصيل المنتج
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${product.price} ج.م',
                      style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}