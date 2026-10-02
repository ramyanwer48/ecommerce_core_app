import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';

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
import '../data/models/product_model.dart';

String toArabicNumbers(String input) {
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  for (int i = 0; i < english.length; i++) {
    input = input.replaceAll(english[i], arabic[i]);
  }
  return input;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;
  final Color pureWhiteBackground = Colors.white;

  final Stream<QuerySnapshot> _bannersStream = FirebaseFirestore.instance.collection('banners').snapshots();

  final PageController _pageController = PageController(initialPage: 0, viewportFraction: 0.92);
  int _currentPage = 0;
  int _totalBanners = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoPlay();
    });
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 4500), (Timer timer) {
      if (_pageController.hasClients && _totalBanners > 0) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _stopAutoPlay() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageController.dispose();
    _stopAutoPlay();
    super.dispose();
  }

  Widget _buildBannerShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 160,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: pureWhiteBackground,
          elevation: 0,
          titleSpacing: 16,
          title: Image.asset('assets/images/RAMY_STORE_ERP_PRIMARY_2400x900.png', height: 38, fit: BoxFit.contain),
          actions: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BlocBuilder<FavoritesCubit, FavoritesState>(
                  builder: (context, favState) {
                    int favCount = 0;
                    if (favState is FavoritesLoaded) favCount = favState.favoriteIds.length;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: Icon(Icons.favorite_border, color: primaryNavy, size: 26),
                          onPressed: () => context.push(Routes.wishlist),
                        ),
                        if (favCount > 0)
                          Positioned(
                            right: 4, top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Text(toArabicNumbers('$favCount'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.person_outline, color: primaryNavy, size: 28),
                  onPressed: () => context.push(Routes.profile),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: brandOrange,
          onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) => const NaasehSheet()),
          child: const Icon(Icons.support_agent, color: Colors.white, size: 28),
        ),
        body: RefreshIndicator(
          color: brandOrange,
          onRefresh: () async => await context.read<HomeCubit>().fetchProducts(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  color: pureWhiteBackground,
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 12),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => context.read<HomeCubit>().searchProducts(value),
                        decoration: InputDecoration(
                          hintText: 'ابحث عن منتج...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo'),
                          prefixIcon: Icon(Icons.search, color: brandOrange, size: 22),
                          filled: true,
                          fillColor: const Color(0xFFF5F7FA),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.transparent)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: brandOrange, width: 1.5)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _bannersStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return _buildBannerShimmer();

                    List<Map<String, dynamic>> displayAds = [];
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      displayAds = snapshot.data!.docs
                          .map((doc) => doc.data() as Map<String, dynamic>)
                          .where((data) => data['isActive'] != false)
                          .toList();
                    }

                    if (displayAds.isEmpty) {
                      displayAds = [
                        {'title': 'أقوى عروض المتجر', 'subtitle': 'خصومات حصرية على المنتجات'},
                        {'title': 'وصل حديثاً!', 'subtitle': 'تصفح أحدث المنتجات التقنية الآن'},
                      ];
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_totalBanners != displayAds.length) setState(() => _totalBanners = displayAds.length);
                    });

                    final int activeIndex = displayAds.isEmpty ? 0 : _currentPage % displayAds.length;

                    return Column(
                      children: [
                        SizedBox(
                          height: 160,
                          child: Listener(
                            onPointerDown: (_) => _stopAutoPlay(),
                            onPointerUp: (_) => _startAutoPlay(),
                            onPointerCancel: (_) => _startAutoPlay(),
                            child: PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) => setState(() => _currentPage = index),
                              itemBuilder: (context, index) {
                                if (displayAds.isEmpty) return const SizedBox.shrink();

                                final actualIndex = index % displayAds.length;
                                final data = displayAds[actualIndex];

                                final title = data['title'] ?? '';
                                final subtitle = data['subtitle'] ?? '';
                                final imageUrl = data['imageUrl'] ?? '';

                                final bool isActivePage = index == _currentPage;

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOutCubic,
                                  margin: EdgeInsets.symmetric(horizontal: 6, vertical: isActivePage ? 2 : 10),
                                  decoration: BoxDecoration(
                                    gradient: imageUrl.isEmpty ? LinearGradient(colors: [primaryNavy, const Color(0xFF1B263B)], begin: Alignment.topRight, end: Alignment.bottomLeft) : null,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: isActivePage
                                        ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))]
                                        : [],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: imageUrl.isEmpty
                                        ? Stack(
                                      children: [
                                        Positioned(left: -20, bottom: -20, child: CircleAvatar(radius: 60, backgroundColor: brandOrange.withAlpha(40))),
                                        Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: Directionality(
                                            textDirection: TextDirection.rtl,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), maxLines: 1),
                                                const SizedBox(height: 8),
                                                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Cairo'), maxLines: 2),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                        : Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return _buildBannerShimmer();
                                      },
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            displayAds.length,
                                (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 6,
                              width: activeIndex == index ? 24 : 8,
                              decoration: BoxDecoration(
                                color: activeIndex == index ? brandOrange : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ),

              SliverToBoxAdapter(
                child: BlocBuilder<HomeCubit, HomeState>(
                  builder: (context, state) {
                    if (state is HomeLoaded && state.categories.isNotEmpty) {
                      final categories = state.categories;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: 16, top: 4, bottom: 8),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text('تسوق حسب القسم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.black87)),
                            ),
                          ),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: SizedBox(
                              height: 38,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: categories.length,
                                itemBuilder: (context, index) {
                                  final cat = categories[index];
                                  final isSelected = context.read<HomeCubit>().currentCategory == cat.name;
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      context.read<HomeCubit>().applyAdvancedFilters(category: cat.name);
                                      setState(() {});
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 18),
                                      decoration: BoxDecoration(
                                        color: isSelected ? brandOrange : Colors.white,
                                        borderRadius: BorderRadius.circular(25),
                                        border: Border.all(color: isSelected ? brandOrange : Colors.grey.shade300),
                                      ),
                                      child: Center(
                                        child: Text(cat.name, style: TextStyle(color: isSelected ? Colors.white : primaryNavy, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(right: 16, top: 20, bottom: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('وصل حديثاً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.black87)),
                  ),
                ),
              ),

              BlocBuilder<HomeCubit, HomeState>(
                builder: (context, state) {
                  if (state is HomeLoading) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));

                  if (state is HomeLoaded) {
                    final products = state.products;
                    return SliverPadding(
                      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 24),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        delegate: SliverChildBuilderDelegate(
                              (context, index) => InteractiveProductCard(product: products[index]),
                          childCount: products.length,
                        ),
                      ),
                    );
                  }
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InteractiveProductCard extends StatefulWidget {
  final ProductModel product;
  const InteractiveProductCard({super.key, required this.product});

  @override
  State<InteractiveProductCard> createState() => _InteractiveProductCardState();
}

class _InteractiveProductCardState extends State<InteractiveProductCard> {
  int _localQty = 0;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    String displayImage = widget.product.images.isNotEmpty ? widget.product.images.first : widget.product.imageUrl;
    final brandOrange = Colors.orange.shade600;
    final primaryNavy = const Color(0xFF0D1B2A);

    int sales = 0;
    try { sales = (widget.product as dynamic).salesCount ?? 0; } catch(e) {}
    bool isBestSeller = sales >= 10;

    double oldPrice = 0;
    try { oldPrice = (widget.product as dynamic).oldPrice ?? 0; } catch(e) {}
    bool hasDiscount = oldPrice > widget.product.price;
    int discountPerc = hasDiscount ? (((oldPrice - widget.product.price) / oldPrice) * 100).toInt() : 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(Routes.productDetails, extra: widget.product);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: displayImage.isNotEmpty
                        ? Image.network(
                      displayImage,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                    )
                        : const Icon(Icons.image, color: Colors.grey, size: 40),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontFamily: 'Cairo', fontSize: 12, height: 1.2),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber.shade600, size: 12),
                            const SizedBox(width: 4),
                            Text(toArabicNumbers('4.5'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            Text(toArabicNumbers(' (120)'), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${toArabicNumbers(widget.product.price.toString())} ج.م',
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14),
                                  ),
                                  if (hasDiscount)
                                    Row(
                                      children: [
                                        Text(
                                          '${toArabicNumbers(oldPrice.toString())} ج.م',
                                          style: const TextStyle(color: Colors.grey, fontSize: 10, decoration: TextDecoration.lineThrough),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(toArabicNumbers('$discountPerc% خصم'), style: TextStyle(color: Colors.green.shade600, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                  else
                                    const SizedBox(height: 14),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isBestSeller)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0056D2),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                  ),
                  child: const Text('الأكثر مبيعاً', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ),
              ),
            Positioned(
              top: 6, left: 6,
              child: BlocBuilder<FavoritesCubit, FavoritesState>(
                builder: (context, favoritesState) {
                  bool isFavorite = false;
                  if (favoritesState is FavoritesLoaded) isFavorite = favoritesState.favoriteIds.contains(widget.product.id);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.vibrate();
                      context.read<FavoritesCubit>().toggleFavorite(widget.product);
                    },
                    child: CircleAvatar(
                      backgroundColor: brandOrange.withOpacity(0.15),
                      radius: 16,
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: brandOrange,
                        size: 18,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 8, left: 8,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _localQty == 0
                    ? GestureDetector(
                  key: const ValueKey('addBtn'),
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    setState(() { _localQty = 1; _isExpanded = false; });
                    context.read<CartCubit>().addToCart(widget.product);
                  },
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Icon(Icons.add, color: Colors.black87, size: 18),
                  ),
                )
                    : !_isExpanded
                    ? GestureDetector(
                  key: const ValueKey('cartBtn'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isExpanded = true);
                  },
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: brandOrange, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(toArabicNumbers('$_localQty'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                )
                    : Container(
                  key: const ValueKey('qtyBtn'),
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: brandOrange, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.vibrate();
                          if (_localQty == 1) {
                            setState(() { _localQty = 0; _isExpanded = false; });
                            context.read<CartCubit>().removeFromCart(widget.product);
                          } else {
                            setState(() => _localQty--);
                          }
                        },
                        child: Icon(_localQty == 1 ? Icons.delete_outline : Icons.remove, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(toArabicNumbers('$_localQty'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _localQty++);
                          context.read<CartCubit>().addToCart(widget.product);
                        },
                        child: const Icon(Icons.add, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}