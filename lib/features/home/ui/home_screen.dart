import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theming/colors.dart';
import '../logic/home_cubit.dart';
import '../logic/home_state.dart';
import 'product_shimmer.dart';
// استدعاءات المفضلة
import '../../wishlist/logic/wishlist_cubit.dart';
import '../../wishlist/logic/wishlist_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // قائمة التصنيفات (يجب أن تتطابق مع ما تكتبه في Firebase)
  final List<String> categories = ['الكل', 'Laptops', 'Accessories', 'Screens'];
  int selectedCategoryIndex = 0; // "الكل" هو الافتراضي

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('RAMY STORE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // أيقونة المفضلة الجديدة
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => context.push(Routes.wishlist),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(Routes.profile),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => context.push(Routes.cart),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. شريط البحث الفوري
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
            child: TextField(
              onChanged: (value) {
                context.read<HomeCubit>().searchProducts(value);
              },
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج (مثال: HP ZBook)...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: ColorsManager.neonBlue),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: ColorsManager.neonBlue, width: 2),
                ),
              ),
            ),
          ),

          // 2. شريط التصنيفات الأفقي
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final isSelected = selectedCategoryIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategoryIndex = index;
                    });
                    context.read<HomeCubit>().filterByCategory(categories[index]);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? ColorsManager.neonBlue : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? ColorsManager.neonBlue : Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Text(
                        categories[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. شبكة المنتجات
          Expanded(
            child: BlocBuilder<HomeCubit, HomeState>(
              builder: (context, state) {
                if (state is HomeLoading) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) => const ProductShimmer(),
                  );
                }

                if (state is HomeLoaded) {
                  final products = state.products;
                  if (products.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('لم نتمكن من العثور على هذا المنتج', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
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
                              // زر المفضلة التفاعلي
                              Positioned(
                                top: 8,
                                left: 8,
                                child: BlocBuilder<WishlistCubit, WishlistState>(
                                  builder: (context, wishlistState) {
                                    final wishlistCubit = context.read<WishlistCubit>();
                                    final isFavorite = wishlistCubit.isInWishlist(product.id);

                                    return CircleAvatar(
                                      backgroundColor: Colors.white.withOpacity(0.9),
                                      radius: 16,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        iconSize: 20,
                                        icon: Icon(
                                          isFavorite ? Icons.favorite : Icons.favorite_border,
                                          color: isFavorite ? Colors.red : Colors.grey,
                                        ),
                                        onPressed: () {
                                          wishlistCubit.toggleWishlist(product);
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }

                if (state is HomeError) {
                  return const Center(child: Text('حدث خطأ في تحميل البيانات', style: TextStyle(color: Colors.red, fontSize: 16)));
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}