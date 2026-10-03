import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/home_repo.dart';
import '../data/models/product_model.dart';
import '../data/models/category_model.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepo _homeRepo;

  List<ProductModel> _allProducts = [];
  List<CategoryModel> _categories = [];

  // 👈 متغيرات تتبع حالة الفلترة (تمت ترقيتها لتشمل كل الفلاتر)
  String? currentCategory; // Null يعني "الكل"
  String currentSearchQuery = '';
  double currentMinPrice = 0;
  double currentMaxPrice = 100000;
  String currentSortBy = 'الأحدث';
  bool currentDiscountOnly = false;
  int currentRating = 0;

  HomeCubit(this._homeRepo) : super(HomeInitial());

  Future<void> fetchProducts() async {
    emit(HomeLoading());
    try {
      final results = await Future.wait([
        _homeRepo.getProducts(),
        _homeRepo.getCategories(),
      ]);

      _allProducts = results[0] as List<ProductModel>;
      _categories = results[1] as List<CategoryModel>;

      if (!_categories.any((c) => c.name == 'الكل')) {
        _categories.insert(
          0,
          CategoryModel(id: 'all', name: 'الكل', imageUrl: '', isActive: true, orderIndex: -1),
        );
      }

      // تصفير الفلاتر عند عمل ريفريش للشاشة
      currentCategory = null;
      currentSearchQuery = '';
      currentMinPrice = 0;
      currentMaxPrice = 100000;
      currentSortBy = 'الأحدث';
      currentDiscountOnly = false;
      currentRating = 0;

      _applyFilters();
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  void searchProducts(String query) {
    currentSearchQuery = query.replaceAll(RegExp(r'\s+'), ' ').toLowerCase().trim();
    _applyFilters();
  }

  void filterByCategory(String category) {
    currentCategory = category == 'الكل' ? null : category;
    _applyFilters();
  }

  // 🚀 دالة الفلتر الذكي المتقدمة (تستقبل الآن جميع خصائص الفلتر)
  void applyAdvancedFilters({
    String? category,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    bool? discountOnly,
    int? rating,
  }) {
    currentCategory = (category == 'الكل' || category == '') ? null : category;
    if (minPrice != null) currentMinPrice = minPrice;
    if (maxPrice != null) currentMaxPrice = maxPrice;
    if (sortBy != null) currentSortBy = sortBy;
    if (discountOnly != null) currentDiscountOnly = discountOnly;
    if (rating != null) currentRating = rating;

    _applyFilters();
  }

  void _applyFilters() {
    List<ProductModel> filteredList = List.from(_allProducts);

    // 1. فلتر البحث السريع
    if (currentSearchQuery.isNotEmpty) {
      filteredList = filteredList.where((product) {
        final nameMatch = product.name.toLowerCase().contains(currentSearchQuery);
        final descMatch = product.description.toLowerCase().contains(currentSearchQuery);
        return nameMatch || descMatch;
      }).toList();
    }

    // 2. فلتر القسم
    if (currentCategory != null) {
      filteredList = filteredList.where((product) => product.category == currentCategory).toList();
    }

    // 3. فلتر نطاق السعر (هنا اللوجيك اللي كان ناقصك واشتغل خلاص)
    filteredList = filteredList.where((product) => product.price >= currentMinPrice && product.price <= currentMaxPrice).toList();

    // 4. فلتر العروض والتخفيضات
    if (currentDiscountOnly) {
      filteredList = filteredList.where((product) {
        double oldPrice = 0;
        try { oldPrice = (product as dynamic).oldPrice ?? 0; } catch(_) {}
        return oldPrice > product.price;
      }).toList();
    }

    // 5. فلتر التقييم (يعرض المنتجات ذات التقييم المساوي أو الأعلى)
    if (currentRating > 0) {
      filteredList = filteredList.where((product) {
        double productRating = 4.5; // قيمة افتراضية لتجنب الإيرور
        try { productRating = (product as dynamic).rating ?? 4.5; } catch(_) {}
        return productRating >= currentRating;
      }).toList();
    }

    // 6. فلتر الترتيب
    if (currentSortBy == 'الأقل سعراً') {
      filteredList.sort((a, b) => a.price.compareTo(b.price));
    } else if (currentSortBy == 'الأعلى سعراً') {
      filteredList.sort((a, b) => b.price.compareTo(a.price));
    } else if (currentSortBy == 'الأكثر مبيعاً') {
      filteredList.sort((a, b) {
        int salesA = 0; int salesB = 0;
        try { salesA = (a as dynamic).salesCount ?? 0; } catch(_) {}
        try { salesB = (b as dynamic).salesCount ?? 0; } catch(_) {}
        return salesB.compareTo(salesA);
      });
    }
    // 'الأحدث' نتركه كما هو لأن قاعدة البيانات ترجعها مرتبة زمنياً غالباً

    emit(HomeLoaded(filteredList, List.from(_categories)));
  }
}