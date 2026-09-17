import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/custom_bottom_sheet.dart';
import '../data/models/product_model.dart';
import '../../../core/di/dependency_injection.dart';
import '../../cart/logic/cart_cubit.dart';
import '../logic/reviews/reviews_cubit.dart';
import '../logic/reviews/reviews_state.dart';
// إضافة استدعاءات المفضلة
import '../logic/favorites/favorites_cubit.dart';
import '../logic/favorites/favorites_state.dart';

class ProductDetailsScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _currentImageIndex = 0;
  String? _selectedVariation;

  @override
  void initState() {
    super.initState();
    if (widget.product.variations.isNotEmpty) {
      _selectedVariation = widget.product.variations.first;
    }
  }

  Widget _buildStars(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (index < rating && rating % 1 != 0) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: size);
        }
      }),
    );
  }

  // الحل الاحترافي (Bottom Sheet) المعتمد في التطبيقات الكبرى
  void _showAddReviewDialog(BuildContext context, ReviewsCubit cubit) {
    double selectedRating = 5.0;
    final nameController = TextEditingController();
    final commentController = TextEditingController();

    CustomBottomSheet.show(
      context: context,
      title: 'أضف تقييمك ⭐️',
      child: StatefulBuilder(
          builder: (context, setStateSheet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setStateSheet(() => selectedRating = index + 1.0);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Icon(
                          index < selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسمك', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'رأيك في المنتج...', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      cubit.addReview(
                        productId: widget.product.id,
                        userName: nameController.text.isNotEmpty ? nameController.text : 'عميل RAMY STORE',
                        rating: selectedRating,
                        comment: commentController.text,
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('نشر التقييم', style: TextStyle(fontSize: 16, color: Colors.white, fontFamily: 'Cairo')),
                  ),
                ),
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> displayImages = widget.product.images.isNotEmpty
        ? widget.product.images
        : (widget.product.imageUrl.isNotEmpty ? [widget.product.imageUrl] : []);

    return BlocProvider(
      create: (context) => getIt<ReviewsCubit>()..fetchReviews(widget.product.id),
      child: Builder(
        builder: (context) {
          final reviewsCubit = context.read<ReviewsCubit>();

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('تفاصيل المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              centerTitle: true,
              backgroundColor: const Color(0xFF000826),
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                BlocConsumer<FavoritesCubit, FavoritesState>(
                  listener: (context, state) {
                    if (state is FavoritesError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.error, style: const TextStyle(fontFamily: 'Cairo')),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    bool isFavorite = false;
                    if (state is FavoritesLoaded) {
                      isFavorite = state.favoriteIds.contains(widget.product.id);
                    }
                    return IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        context.read<FavoritesCubit>().toggleFavorite(widget.product);
                      },
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 300,
                  color: const Color(0xFFF5F7FA),
                  child: displayImages.isEmpty
                      ? const Icon(Icons.image_not_supported, size: 100, color: Colors.grey)
                      : Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      PageView.builder(
                        itemCount: displayImages.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return Image.network(displayImages[index], fit: BoxFit.contain);
                        },
                      ),
                      if (displayImages.length > 1)
                        Positioned(
                          bottom: 16,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              displayImages.length,
                                  (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentImageIndex == index ? 20 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentImageIndex == index ? const Color(0xFF00D4FF) : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.product.name,
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${widget.product.price} ج.م',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF007BFF), fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          BlocBuilder<ReviewsCubit, ReviewsState>(
                            builder: (context, state) {
                              double avg = 0.0;
                              int count = 0;
                              if (state is ReviewsLoaded) {
                                avg = state.averageRating;
                                count = state.reviews.length;
                              }
                              return Row(
                                children: [
                                  _buildStars(avg, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${avg.toStringAsFixed(1)} ($count تقييم)',
                                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                widget.product.inStock ? Icons.check_circle : Icons.cancel,
                                color: widget.product.inStock ? Colors.green : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.product.inStock ? 'متوفر في المخزن' : 'نفذت الكمية',
                                style: TextStyle(
                                    color: widget.product.inStock ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo'
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          if (widget.product.variations.isNotEmpty) ...[
                            const Text('الخيارات المتاحة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: widget.product.variations.map((variation) {
                                final isSelected = _selectedVariation == variation;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedVariation = variation;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF00D4FF) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSelected ? const Color(0xFF00D4FF) : Colors.grey.shade300),
                                    ),
                                    child: Text(
                                      variation,
                                      style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.black87,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontFamily: 'Cairo'
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const Divider(height: 24),
                          ],
                          const Text('الوصف:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                          const SizedBox(height: 8),
                          Text(
                            widget.product.description,
                            style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5, fontFamily: 'Cairo'),
                          ),
                          const Divider(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المراجعات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              TextButton.icon(
                                onPressed: () => _showAddReviewDialog(context, reviewsCubit),
                                icon: const Icon(Icons.edit, size: 18, color: Color(0xFF007BFF)),
                                label: const Text('أضف تقييمك', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007BFF), fontFamily: 'Cairo')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          BlocBuilder<ReviewsCubit, ReviewsState>(
                            builder: (context, state) {
                              if (state is ReviewsLoading) {
                                return const Center(child: CircularProgressIndicator());
                              } else if (state is ReviewsLoaded) {
                                if (state.reviews.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(child: Text('لا توجد تقييمات بعد. كن أول من يقيم هذا المنتج!', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                                  );
                                }
                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: state.reviews.length,
                                  separatorBuilder: (context, index) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final review = state.reviews[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                              Text(review.date, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Cairo')),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          _buildStars(review.rating, size: 14),
                                          const SizedBox(height: 8),
                                          Text(review.comment, style: const TextStyle(fontSize: 14, fontFamily: 'Cairo')),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              } else if (state is ReviewsError) {
                                return Center(child: Text(state.error, style: const TextStyle(color: Colors.red, fontFamily: 'Cairo')));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: SizedBox(
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final String finalName = _selectedVariation != null
                        ? '${widget.product.name} ($_selectedVariation)'
                        : widget.product.name;

                    // 👇 التعديل هنا: أضفنا price: widget.product.price لتتوافق مع الموديل الجديد
                    final productToAdd = ProductModel(
                      id: widget.product.id,
                      name: finalName,
                      description: widget.product.description,
                      price: widget.product.price, // 👈 تم إضافتها بنجاح
                      imageUrl: widget.product.imageUrl,
                      images: widget.product.images,
                      variations: widget.product.variations,
                      category: widget.product.category,
                      inStock: widget.product.inStock,
                      isActive: widget.product.isActive,
                      batches: widget.product.batches,
                    );

                    getIt<CartCubit>().addToCart(productToAdd);

                    final optionText = _selectedVariation != null ? '($_selectedVariation) ' : '';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم إضافة ${widget.product.name} $optionTextللسلة بنجاح!', style: const TextStyle(fontFamily: 'Cairo')),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('أضف للسلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}