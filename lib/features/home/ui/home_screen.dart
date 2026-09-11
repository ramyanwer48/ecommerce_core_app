import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theming/colors.dart';
import '../../../core/widgets/custom_bottom_sheet.dart';
import '../logic/home_cubit.dart';
import '../logic/home_state.dart';
import 'product_shimmer.dart';
import '../logic/favorites/favorites_cubit.dart';
import '../logic/favorites/favorites_state.dart';
import '../data/models/category_model.dart'; // 👈 استدعاء موديل الأقسام الجديد

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // 🎛️ دالة عرض الفلتر الاحترافي
  void _showFilterSheet(BuildContext context) {
    final cubit = context.read<HomeCubit>();

    // سحب القيم الحالية من الـ Cubit
    String localCategory = cubit.currentCategory;
    double localMin = cubit.currentMinPrice;
    double localMax = cubit.currentMaxPrice;
    String localSortBy = cubit.currentSortBy;

    // 👈 سحب الأقسام الديناميكية من الـ State الحالي
    List<CategoryModel> sheetCategories = [];
    if (cubit.state is HomeLoaded) {
      sheetCategories = (cubit.state as HomeLoaded).categories;
    }

    CustomBottomSheet.show(
      context: context,
      title: 'تصفية وترتيب 🎛️',
      child: StatefulBuilder(
          builder: (context, setStateSheet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. الترتيب
                const Text('الترتيب حسب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [
                    _buildChoiceChip('الافتراضي', localSortBy == 'none', () {
                      setStateSheet(() => localSortBy = 'none');
                      cubit.applyAdvancedFilters(sortBy: 'none');
                    }),
                    _buildChoiceChip('الأقل سعراً', localSortBy == 'price_asc', () {
                      setStateSheet(() => localSortBy = 'price_asc');
                      cubit.applyAdvancedFilters(sortBy: 'price_asc');
                    }),
                    _buildChoiceChip('الأعلى سعراً', localSortBy == 'price_desc', () {
                      setStateSheet(() => localSortBy = 'price_desc');
                      cubit.applyAdvancedFilters(sortBy: 'price_desc');
                    }),
                  ],
                ),
                const Divider(height: 32),

                // 2. نطاق السعر
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('نطاق السعر:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      '${localMin.toInt()} - ${localMax.toInt()} ج.م',
                      style: const TextStyle(color: ColorsManager.neonBlue, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                RangeSlider(
                  values: RangeValues(localMin, localMax),
                  min: 0,
                  max: 100000,
                  divisions: 100,
                  activeColor: ColorsManager.neonBlue,
                  inactiveColor: Colors.grey.shade300,
                  onChanged: (values) {
                    setStateSheet(() {
                      localMin = values.start;
                      localMax = values.end;
                    });
                    cubit.applyAdvancedFilters(minPrice: localMin, maxPrice: localMax);
                  },
                ),
                const Divider(height: 32),

                // 3. التصنيفات (الديناميكية)
                const Text('التصنيف:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: sheetCategories.map((cat) {
                    return _buildChoiceChip(cat.name, localCategory == cat.name, () {
                      setStateSheet(() => localCategory = cat.name);
                      // تم حذف setState الخاصة بالشاشة الرئيسية لأن الكيوبيت سيتولى الأمر
                      cubit.applyAdvancedFilters(category: cat.name);
                    });
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // 4. زر التطبيق الذكي
                BlocBuilder<HomeCubit, HomeState>(
                    bloc: cubit,
                    builder: (context, state) {
                      int count = 0;
                      if (state is HomeLoaded) count = state.products.length;

                      bool hasResults = count > 0;

                      return SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasResults ? ColorsManager.neonBlue : Colors.grey.shade400,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: hasResults ? () => Navigator.pop(context) : null,
                          child: Text(
                            hasResults ? 'عرض $count منتج 🚀' : 'لا توجد منتجات مطابقة',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      );
                    }
                ),
              ],
            );
          }
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: ColorsManager.neonBlue,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? ColorsManager.neonBlue : Colors.grey.shade300),
      ),
    );
  }

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
          IconButton(icon: const Icon(Icons.favorite), onPressed: () => context.push(Routes.wishlist)),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => context.push(Routes.profile)),
          IconButton(icon: const Icon(Icons.shopping_cart), onPressed: () => context.push(Routes.cart)),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocListener<FavoritesCubit, FavoritesState>(
        listener: (context, state) {
          if (state is FavoritesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
            );
          }
        },
        child: Column(
          children: [
            // 1. شريط البحث
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
              child: TextField(
                onChanged: (value) => context.read<HomeCubit>().searchProducts(value),
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: ColorsManager.neonBlue),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.tune, color: ColorsManager.neonBlue),
                    onPressed: () => _showFilterSheet(context),
                  ),
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

            // 2. شريط التصنيفات الأفقي (الديناميكي)
            BlocBuilder<HomeCubit, HomeState>(
              builder: (context, state) {
                if (state is HomeLoaded) {
                  final categories = state.categories;
                  final currentCubitCategory = context.read<HomeCubit>().currentCategory;

                  return SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = currentCubitCategory == cat.name;

                        return GestureDetector(
                          onTap: () {
                            // التحديث يتم مباشرة عبر الكيوبيت
                            context.read<HomeCubit>().applyAdvancedFilters(category: cat.name);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(left: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? ColorsManager.neonBlue : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? ColorsManager.neonBlue : Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 👈 إضافة دعم ذكي لظهور أيقونة القسم لو موجودة في الفايربيز
                                if (cat.imageUrl.isNotEmpty) ...[
                                  Image.network(
                                    cat.imageUrl,
                                    width: 20,
                                    height: 20,
                                    color: isSelected ? Colors.white : ColorsManager.neonBlue,
                                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
                // شكل تحميل وهمي للأقسام
                return const SizedBox(height: 60);
              },
            ),

            // 3. شبكة المنتجات
            Expanded(
              child: BlocBuilder<HomeCubit, HomeState>(
                builder: (context, state) {
                  if (state is HomeLoading) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: 16, mainAxisSpacing: 16,
                      ),
                      itemCount: 6,
                      itemBuilder: (context, index) => const ProductShimmer(),
                    );
                  }

                  if (state is HomeLoaded) {
                    final products = state.products;
                    if (products.isEmpty) {
                      return RefreshIndicator(
                        color: ColorsManager.neonBlue,
                        onRefresh: () async {
                          await context.read<HomeCubit>().fetchProducts();
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                  'لا توجد منتجات متاحة حالياً',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      color: ColorsManager.neonBlue,
                      onRefresh: () async {
                        await context.read<HomeCubit>().fetchProducts();
                      },
                      child: GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: 16, mainAxisSpacing: 16,
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
                                  Positioned(
                                    top: 8, left: 8,
                                    child: BlocBuilder<FavoritesCubit, FavoritesState>(
                                      builder: (context, favoritesState) {
                                        bool isFavorite = false;
                                        if (favoritesState is FavoritesLoaded) isFavorite = favoritesState.favoriteIds.contains(product.id);

                                        return CircleAvatar(
                                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                                          radius: 16,
                                          child: IconButton(
                                            padding: EdgeInsets.zero, iconSize: 20,
                                            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.grey),
                                            onPressed: () => context.read<FavoritesCubit>().toggleFavorite(product),
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
                      ),
                    );
                  }

                  if (state is HomeError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SelectableText( // 👈 استخدمنا SelectableText عشان تقدر تنسخ الرابط بسهولة
                          state.error, // 👈 هنا هيظهرلك سبب الرفض والرابط السري بتاع الفايربيز
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}