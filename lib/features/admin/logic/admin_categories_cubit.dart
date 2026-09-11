import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/data/models/category_model.dart';
import '../data/repos/admin_categories_repo.dart';
// 👈 تأكد من مسار الموديل حسب ترتيب مجلداتك

// --- States ---
abstract class AdminCategoriesState {}
class AdminCategoriesInitial extends AdminCategoriesState {}
class AdminCategoriesLoading extends AdminCategoriesState {}
class AdminCategoriesLoaded extends AdminCategoriesState {
  final List<CategoryModel> categories;
  AdminCategoriesLoaded(this.categories);
}
class AdminCategoriesError extends AdminCategoriesState {
  final String error;
  AdminCategoriesError(this.error);
}

// --- Cubit ---
class AdminCategoriesCubit extends Cubit<AdminCategoriesState> {
  final AdminCategoriesRepo _repo;

  AdminCategoriesCubit(this._repo) : super(AdminCategoriesInitial());

  // جلب الأقسام
  Future<void> loadCategories() async {
    emit(AdminCategoriesLoading());
    try {
      final cats = await _repo.getAllCategories();
      emit(AdminCategoriesLoaded(cats));
    } catch (e) {
      emit(AdminCategoriesError(e.toString()));
    }
  }

  // إضافة قسم جديد (مثل: عروض العيد)
  Future<void> addNewCategory({required String name, required String imageUrl}) async {
    try {
      // نحدد الترتيب كآخر عنصر في القائمة حالياً
      int newIndex = 0;
      if (state is AdminCategoriesLoaded) {
        newIndex = (state as AdminCategoriesLoaded).categories.length;
      }

      final newCat = CategoryModel(
        id: '', // الفايربيز هيعمله Generate
        name: name,
        imageUrl: imageUrl,
        orderIndex: newIndex,
        isActive: true,
      );

      await _repo.addCategory(newCat);
      await loadCategories(); // تحديث الشاشة فوراً
    } catch (e) {
      emit(AdminCategoriesError(e.toString()));
    }
  }

  // إخفاء أو إظهار قسم بضغطة زر
  Future<void> toggleStatus(String id, bool currentStatus) async {
    try {
      await _repo.toggleCategoryStatus(id, currentStatus);
      await loadCategories(); // تحديث الشاشة فوراً
    } catch (e) {
      emit(AdminCategoriesError(e.toString()));
    }
  }
}