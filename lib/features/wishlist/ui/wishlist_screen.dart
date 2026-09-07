import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';
import '../../home/data/models/product_model.dart';
import '../logic/wishlist_cubit.dart';
import '../logic/wishlist_state.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('المفضلة ❤️', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocBuilder<WishlistCubit, WishlistState>(
        builder: (context, state) {
          final cubit = context.read<WishlistCubit>();

          List<ProductModel> items = [];
          if (state is WishlistUpdated) {
            items = state.wishlistItems;
          }

          // إذا كانت المفضلة فارغة
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('المفضلة فارغة 💔', style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          // عرض منتجات المفضلة في شبكة
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final product = items[index];
              return GestureDetector(
                onTap: () => context.push(Routes.productDetails, extra: product),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: product.imageUrl.isNotEmpty
                                  ? Image.network(product.imageUrl, fit: BoxFit.cover, width: double.infinity)
                                  : Container(color: Colors.grey[200], child: const Icon(Icons.image, size: 50)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${product.price} ج.م', style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // زر إزالة من المفضلة
                      Positioned(
                        top: 8,
                        left: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            onPressed: () => cubit.toggleWishlist(product),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}