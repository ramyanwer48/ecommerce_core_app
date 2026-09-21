import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/routing/routes.dart';
import '../../../core/widgets/custom_bottom_sheet.dart';
import '../logic/home_cubit.dart';
import '../logic/home_state.dart';
import 'product_shimmer.dart';
import '../logic/favorites/favorites_cubit.dart';
import '../logic/favorites/favorites_state.dart';
import '../data/models/category_model.dart';
import '../../cart/logic/cart_cubit.dart';
import '../../cart/logic/cart_state.dart';
import '../../ai_assistant/ui/naaseh_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // 👈 تعريف الـ Stream هنا
  late Stream<DocumentSnapshot> _bannerStream;

  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;
  final Color pureWhiteBackground = Colors.white;

  @override
  void initState() {
    super.initState();
    // 👈 إعطاء القيمة للـ Stream هنا يحل مشكلة الـ LateInitializationError تماماً
    _bannerStream = FirebaseFirestore.instance.collection('settings').doc('banner').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showFilterSheet(BuildContext context) {
    HapticFeedback.vibrate();
    final cubit = context.read<HomeCubit>();

    String localCategory = cubit.currentCategory;
    double localMin = cubit.currentMinPrice;
    double localMax = cubit.currentMaxPrice;
    String localSortBy = cubit.currentSortBy;

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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('نطاق السعر:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '${localMin.toInt()} - ${localMax.toInt()} ج.م',
                    style: TextStyle(color: brandOrange, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              RangeSlider(
                values: RangeValues(localMin, localMax),
                min: 0,
                max: 100000,
                divisions: 100,
                activeColor: brandOrange,
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

              const Text('التصنيف:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: sheetCategories.map((cat) {
                  return _buildChoiceChip(cat.name, localCategory == cat.name, () {
                    setStateSheet(() => localCategory = cat.name);
                    cubit.applyAdvancedFilters(category: cat.name);
                  });
                }).toList(),
              ),
              const SizedBox(height: 32),

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
                        backgroundColor: hasResults ? brandOrange : Colors.grey.shade400,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: hasResults ? () => Navigator.pop(context) : null,
                      child: Text(
                        hasResults ? 'عرض $count منتج 🚀' : 'لا توجد منتجات مطابقة',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onTap();
      },
      selectedColor: brandOrange,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? brandOrange : Colors.grey.shade300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: pureWhiteBackground,

        appBar: AppBar(
          backgroundColor: pureWhiteBackground,
          elevation: 0,
          titleSpacing: 16,
          title: Image.asset(
            'assets/images/RAMY_STORE_ERP_PRIMARY_2400x900.png',
            height: 44,
            fit: BoxFit.contain,
          ),
          actions: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: currentUser != null
                      ? FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get()
                      : Future.value(null),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                      final role = snapshot.data!.get('role') ?? 'customer';
                      if (role == 'admin') {
                        return IconButton(
                          icon: Icon(Icons.admin_panel_settings, color: brandOrange),
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            context.push(Routes.adminDashboard);
                          },
                          tooltip: 'لوحة التحكم',
                        );
                      }
                    }
                    return const SizedBox.shrink();
                  },
                ),
                BlocBuilder<FavoritesCubit, FavoritesState>(
                  builder: (context, favState) {
                    int favCount = 0;
                    if (favState is FavoritesLoaded) {
                      favCount = favState.favoriteIds.length;
                    }
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: Icon(Icons.favorite, color: primaryNavy),
                          onPressed: () {
                            HapticFeedback.vibrate();
                            context.push(Routes.wishlist);
                          },
                        ),
                        if (favCount > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                '$favCount',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.person_outline, color: primaryNavy),
                  onPressed: () {
                    HapticFeedback.vibrate();
                    context.push(Routes.profile);
                  },
                ),
                BlocBuilder<CartCubit, CartState>(
                  builder: (context, state) {
                    int badgeCount = 0;
                    if (state is CartUpdated) {
                      badgeCount = state.totalQuantity;
                    }
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: Icon(Icons.shopping_cart, color: primaryNavy),
                          onPressed: () {
                            HapticFeedback.vibrate();
                            context.push(Routes.cart);
                          },
                        ),
                        if (badgeCount > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Text(
                                '$badgeCount',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton(
          backgroundColor: brandOrange,
          elevation: 4,
          onPressed: () {
            HapticFeedback.vibrate();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const NaasehSheet(),
            );
          },
          child: const Icon(Icons.support_agent, color: Colors.white, size: 28),
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
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (value) {
                      setState(() {});
                      context.read<HomeCubit>().searchProducts(value);
                    },
                    decoration: InputDecoration(
                      hintText: 'ابحث عن منتج...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Cairo'),
                      prefixIcon: Icon(Icons.search, color: brandOrange),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  context.read<HomeCubit>().searchProducts('');
                                });
                                _searchFocusNode.unfocus();
                              },
                            ),
                          IconButton(
                            icon: Icon(Icons.tune, color: brandOrange),
                            onPressed: () {
                              _searchFocusNode.unfocus();
                              _showFilterSheet(context);
                            },
                          ),
                        ],
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: brandOrange, width: 2),
                      ),
                    ),
                  ),
                ),
              ),

              // 👈 استخدام الـ Stream المجهز مسبقاً لحل خطأ LateInitializationError
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _bannerStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    if (snapshot.hasError) {
                      return const SizedBox.shrink();
                    }

                    String title = 'أقوى عروض أنظمة الـ ERP والتقنية';
                    String subtitle = 'تسوق الآن واحصل على خصومات حصرية على الأجهزة والاكسسوارات.';
                    bool isActive = true;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      title = (data?['title']?.toString().isNotEmpty == true) ? data!['title'] : title;
                      subtitle = (data?['subtitle']?.toString().isNotEmpty == true) ? data!['subtitle'] : subtitle;
                      isActive = data?['isActive'] ?? true;
                    }

                    if (!isActive) return const SizedBox.shrink();

                    return Container(
                      width: double.infinity,
                      height: 130,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryNavy, const Color(0xFF1B263B)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: -20,
                            bottom: -20,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: brandOrange.withAlpha(40),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: brandOrange,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'عرض خاص 🔥',
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (currentUser != null)
                                        const Expanded(
                                          child: Text(
                                            'أهلاً بك يا هندسة 🚀',
                                            style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Cairo'),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    title,
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Cairo'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              BlocBuilder<HomeCubit, HomeState>(
                builder: (context, state) {
                  if (state is HomeLoaded) {
                    final categories = state.categories;
                    final currentCubitCategory = context.read<HomeCubit>().currentCategory;

                    return SizedBox(
                      height: 60,
                      child: ListView.builder(
                        reverse: true,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = currentCubitCategory == cat.name;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _searchController.clear();
                              _searchFocusNode.unfocus();
                              final cubit = context.read<HomeCubit>();
                              cubit.searchProducts('');
                              cubit.applyAdvancedFilters(category: cat.name);
                              setState(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? brandOrange : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? brandOrange : Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (cat.imageUrl.isNotEmpty) ...[
                                    Image.network(
                                      cat.imageUrl,
                                      width: 20,
                                      height: 20,
                                      color: isSelected ? Colors.white : brandOrange,
                                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                        color: isSelected ? Colors.white : primaryNavy,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Cairo'
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
                  return const SizedBox(height: 60);
                },
              ),

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
                          color: brandOrange,
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
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Cairo')
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: brandOrange,
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
                            final product = products.length > index ? products[index] : null;
                            if (product == null) return const SizedBox.shrink();

                            return GestureDetector(
                              onTap: () {
                                _searchFocusNode.unfocus();
                                HapticFeedback.vibrate();
                                context.push(Routes.productDetails, extra: product);
                              },
                              child: Card(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
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
                                          padding: const EdgeInsets.all(10.0),
                                          child: Directionality(
                                            textDirection: TextDirection.rtl,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    product.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontFamily: 'Cairo', fontSize: 15)
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                    '${product.price} ج.م',
                                                    style: TextStyle(color: brandOrange, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)
                                                ),
                                              ],
                                            ),
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
                                            backgroundColor: Colors.white.withAlpha(240),
                                            radius: 16,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.grey),
                                              onPressed: () {
                                                HapticFeedback.vibrate();
                                                context.read<FavoritesCubit>().toggleFavorite(product);
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
                        ),
                      );
                    }

                    if (state is HomeError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SelectableText(
                            state.error,
                            style: const TextStyle(color: Colors.red, fontSize: 16, fontFamily: 'Cairo'),
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
      ),
    );
  }
}