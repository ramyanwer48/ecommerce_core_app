import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/admin_repo.dart';
import 'add_product_state.dart';

class AddProductCubit extends Cubit<AddProductState> {
  final AdminRepo _adminRepo;
  AddProductCubit(this._adminRepo) : super(AddProductInitial());

  Future<void> addProductToFirestore({
    required String name,
    required double price,
    required double costPrice, // 👈 استقبال سعر التكلفة هنا
    required String category,
    required String description,
    required File mainImageFile,
    required List<File> extraImageFiles,
    required List<String> variations,
    required bool inStock,
    required int stockQuantity,
  }) async {
    emit(AddProductLoading());
    try {
      // 1. رفع الصورة الأساسية وجلب رابطها
      String mainImageUrl = await _adminRepo.uploadProductImage(mainImageFile);

      // 2. رفع كل الصور الإضافية وجلب روابطها سحابياً
      List<String> extraImageUrls = [];
      for (var file in extraImageFiles) {
        String url = await _adminRepo.uploadProductImage(file);
        extraImageUrls.add(url);
      }

      // 3. تجميع الصورة الرئيسية مع الصور الإضافية في مصفوفة واحدة للمعرض
      List<String> allImages = [mainImageUrl, ...extraImageUrls];

      // 4. حفظ المنتج في فايربيز بالبيانات الكاملة شاملة المخزون وسعر التكلفة
      await _adminRepo.addProduct(
        name: name,
        price: price,
        costPrice: costPrice, // 👈 تمرير سعر التكلفة إلى الـ Repo
        category: category,
        description: description,
        imageUrl: mainImageUrl,
        images: allImages,
        variations: variations,
        inStock: inStock,
        stockQuantity: stockQuantity,
      );

      emit(AddProductSuccess());
    } catch (e) {
      emit(AddProductError('فشل رفع الصور أو النشر: ${e.toString()}'));
    }
  }
}