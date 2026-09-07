import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/home_repo.dart';
import '../data/models/product_model.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepo _homeRepo;

  // حفظ النسخة الأصلية من المنتجات لفلترتها محلياً
  List<ProductModel> _allProducts = [];

  HomeCubit(this._homeRepo) : super(HomeInitial());

  Future<void> fetchProducts() async {
    emit(HomeLoading());
    try {
      _allProducts = await _homeRepo.getProducts();
      emit(HomeLoaded(_allProducts));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  // دالة الفلترة الجديدة
  void filterByCategory(String category) {
    if (category == 'الكل') {
      emit(HomeLoaded(_allProducts)); // عرض كل المنتجات
    } else {
      final filteredList = _allProducts.where((product) => product.category == category).toList();
      emit(HomeLoaded(filteredList)); // عرض المنتجات المطابقة فقط
    }
  } // <-- تم إغلاق قوس دالة الفلترة هنا

  // دالة البحث الفوري (مستقلة وتعمل بشكل صحيح الآن)
  void searchProducts(String query) {
    if (query.isEmpty) {
      // إذا كان مربع البحث فارغاً، نعرض كل المنتجات
      emit(HomeLoaded(_allProducts));
    } else {
      // البحث عن أي منتج يحتوي اسمه على الحروف المكتوبة (مع تجاهل حالة الأحرف)
      final searchedList = _allProducts
          .where((product) => product.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      emit(HomeLoaded(searchedList));
    }
  }
}