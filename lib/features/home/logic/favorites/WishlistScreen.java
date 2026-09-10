import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theming/colors.dart';
import '../../home/logic/favorites/favorites_cubit.dart';
import '../../home/logic/favorites/favorites_state.dart';
import '../../home/data/models/product_model.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('المفضلة', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<FavoritesCubit, FavoritesState>(
        builder: (context, state) {
          if (state is FavoritesLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)));
          }

          if (state is FavoritesError) {
            return Center(
              child: Text(state.error, style: const TextStyle(color: Colors.red, fontSize: 16)),
            );
          }

          if (state is FavoritesLoaded) {
            if (state.favoriteProducts.isEmpty) {
              return _buildEmptyWishlist();
            }

            // 👈 إضافة السحب للتحديث في المفضلة
            return RefreshIndicator(
              color: ColorsManager.neonBlue,
              onRefresh: () async {
                // استدعاء دالة تحديث المفضلة (تأكد من اسم الدالة في الكيوبيت عندك)
                await context.read<FavoritesCubit>().getFavorites(); 
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(), // 👈 إجبار السحب حتى لو المنتجات قليلة
                padding: const EdgeInsets.all(16),
                itemCount: state.favoriteProducts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = state.favoriteProducts[index];
                  
                  // 👈 قراءة حالة المنتج (الافتراضي true لو مش موجودة لسه)
                  // ملاحظة: هنضيف isActive للموديل في الخطوة الجاية
                  final bool isActive = item.isActive ?? true;

                  return Card(
                    color: isActive ? Colors.white : Colors.grey.shade100, // لون باهت للمنتج المخفي
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      // 👈 تعطيل الضغط لو المنتج غير متاح
                      onTap: isActive ? () {
                        final tempProduct = ProductModel(
                          id: item.productId,
                          name: item.name,
                          description: 'جاري تحميل التفاصيل...',
                          price: item.price,
                          imageUrl: item.imageUrl,
                          images: [],
                          variations: [],
                          category: '',
                          inStock: true,
                          isActive: isActive,
                        );
                        context.push(Routes.productDetails, extra: tempProduct);
                      } : null, 
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // 👈 تقليل شفافية الصورة للمنتج المخفي
                            Opacity(
                              opacity: isActive ? 1.0 : 0.4,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  item.imageUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.image)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 16, 
                                      fontWeight: FontWeight.bold,
                                      // 👈 شطب الاسم للمنتج المخفي
                                      decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                      color: isActive ? Colors.black : Colors.grey.shade600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${item.price} ج.م',
                                    style: TextStyle(
                                      fontSize: 16, 
                                      color: isActive ? const Color(0xFF007BFF) : Colors.grey.shade500, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                  // 👈 بادج التنبيه
                                  if (!isActive)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text('غير متوفر حالياً', style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
                            // 👈 زر الحذف من المفضلة (يظل يعمل دائماً)
                            IconButton(
                              icon: const Icon(Icons.favorite, color: Colors.red, size: 28),
                              onPressed: () {
                                final tempProduct = ProductModel(
                                  id: item.productId,
                                  name: item.name,
                                  description: '',
                                  price: item.price,
                                  imageUrl: item.imageUrl,
                                  images: [],
                                  variations: [],
                                  category: '',
                                  inStock: true,
                                );
                                context.read<FavoritesCubit>().toggleFavorite(tempProduct);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyWishlist() {
    // ... (نفس كود الشاشة الفارغة بتاعك بدون تعديل)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 24),
          const Text(
            'قائمة المفضلة فارغة',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Text(
            'تصفح المنتجات واضغط على القلب لإضافتها هنا',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}