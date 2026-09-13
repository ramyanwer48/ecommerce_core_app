import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/home_repo.dart';
import '../data/models/product_model.dart';
import '../data/models/category_model.dart'; // 👈 استدعاء الأقسام
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepo _homeRepo;

  // القوائم الأصلية
  List<ProductModel> _allProducts = [];
  List<CategoryModel> _categories = []; // 👈 متغير حفظ الأقسام

  // متغيرات تتبع حالة الفلترة
  String currentCategory = 'الكل';
  String currentSearchQuery = '';
  double currentMinPrice = 0;
  double currentMaxPrice = 100000;
  String currentSortBy = 'none';

  HomeCubit(this._homeRepo) : super(HomeInitial());

  // 🚀 تم ترقية الدالة لجلب المنتجات والأقسام معاً بالتوازي
  Future<void> fetchProducts() async {
    emit(HomeLoading());
    try {
      // Future.wait بتنفذ الطلبين مع بعض في نفس الوقت لتسريع التحميل
      final results = await Future.wait([
        _homeRepo.getProducts(),
        _homeRepo.getCategories(),
      ]);

      _allProducts = results[0] as List<ProductModel>;
      _categories = results[1] as List<CategoryModel>;

      // 👈 إضافة قسم "الكل" افتراضياً في أول القائمة برمجياً عشان العميل يقدر يلغي الفلتر
      if (!_categories.any((c) => c.name == 'الكل')) {
        _categories.insert(
          0,
          CategoryModel(id: 'all', name: 'الكل', imageUrl: '', isActive: true, orderIndex: -1),
        );
      }

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
    currentCategory = category;
    _applyFilters();
  }

  void applyAdvancedFilters({
    String? category,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
  }) {
    if (category != null) currentCategory = category;
    if (minPrice != null) currentMinPrice = minPrice;
    if (maxPrice != null) currentMaxPrice = maxPrice;
    if (sortBy != null) currentSortBy = sortBy;

    _applyFilters();
  }

  void _applyFilters() {
    List<ProductModel> filteredList = List.from(_allProducts);

    if (currentCategory != 'الكل') {
      filteredList = filteredList.where((product) => product.category == currentCategory).toList();
    }

    if (currentSearchQuery.isNotEmpty) {
      filteredList = filteredList.where((product) {
        final nameMatch = product.name.toLowerCase().contains(currentSearchQuery);
        final descMatch = product.description.toLowerCase().contains(currentSearchQuery);
        return nameMatch || descMatch;
      }).toList();
    }

    filteredList = filteredList.where((product) => product.price >= currentMinPrice && product.price <= currentMaxPrice).toList();

    if (currentSortBy == 'price_asc') {
      filteredList.sort((a, b) => a.price.compareTo(b.price));
    } else if (currentSortBy == 'price_desc') {
      filteredList.sort((a, b) => b.price.compareTo(a.price));
    }

    // 👈 تمرير المنتجات المفلترة ومعهم الأقسام لشاشة العرض
    emit(HomeLoaded(filteredList, List.from(_categories)));
  }
}