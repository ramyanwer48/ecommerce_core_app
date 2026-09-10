import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/home_repo.dart';
import '../data/models/product_model.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepo _homeRepo;

  // القائمة الأصلية
  List<ProductModel> _allProducts = [];

  // متغيرات تتبع حالة الفلترة (جعلناها عامة لتقرأها واجهة المستخدم)
  String currentCategory = 'الكل';
  String currentSearchQuery = '';
  double currentMinPrice = 0;
  double currentMaxPrice = 100000; // حد أقصى افتراضي
  String currentSortBy = 'none'; // 'price_asc' (الأقل للأعلى), 'price_desc' (الأعلى للأقل)

  HomeCubit(this._homeRepo) : super(HomeInitial());

  Future<void> fetchProducts() async {
    emit(HomeLoading());
    try {
      _allProducts = await _homeRepo.getProducts();
      _applyFilters();
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  // البحث السريع
  void searchProducts(String query) {
    currentSearchQuery = query.toLowerCase().trim();
    _applyFilters();
  }

  // فلترة التصنيفات السريعة
  void filterByCategory(String category) {
    currentCategory = category;
    _applyFilters();
  }

  // الفلترة المتقدمة (من الـ Bottom Sheet)
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

  // 🚀 المحرك الأساسي (يجمع كل الفلاتر معاً)
  void _applyFilters() {
    List<ProductModel> filteredList = List.from(_allProducts);

    // 1. التصنيف
    if (currentCategory != 'الكل') {
      filteredList = filteredList.where((product) => product.category == currentCategory).toList();
    }

    // 2. البحث النصي
    if (currentSearchQuery.isNotEmpty) {
      filteredList = filteredList.where((product) {
        final nameMatch = product.name.toLowerCase().contains(currentSearchQuery);
        final descMatch = product.description.toLowerCase().contains(currentSearchQuery);
        return nameMatch || descMatch;
      }).toList();
    }

    // 3. نطاق السعر
    filteredList = filteredList.where((product) => product.price >= currentMinPrice && product.price <= currentMaxPrice).toList();

    // 4. الترتيب (Sorting)
    if (currentSortBy == 'price_asc') {
      filteredList.sort((a, b) => a.price.compareTo(b.price)); // الأقل سعراً
    } else if (currentSortBy == 'price_desc') {
      filteredList.sort((a, b) => b.price.compareTo(a.price)); // الأعلى سعراً
    }

    emit(HomeLoaded(filteredList));
  }
}