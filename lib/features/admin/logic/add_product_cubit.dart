import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/admin_repo.dart';
import 'add_product_state.dart';

class AddProductCubit extends Cubit<AddProductState> {
  final AdminRepo _adminRepo;
  AddProductCubit(this._adminRepo) : super(AddProductInitial());

  Future<void> addProductToFirestore({
    required String name,
    required double price,
    required String category,
    required String description,
    required String imageUrl,
    required bool inStock,
  }) async {
    emit(AddProductLoading());
    try {
      await _adminRepo.addProduct(
        name: name,
        price: price,
        category: category,
        description: description,
        imageUrl: imageUrl,
        inStock: inStock,
      );
      emit(AddProductSuccess());
    } catch (e) {
      emit(AddProductError('فشل إضافة المنتج: ${e.toString()}'));
    }
  }
}