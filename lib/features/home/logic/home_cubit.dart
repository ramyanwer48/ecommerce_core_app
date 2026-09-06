import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/home_repo.dart'; // مسار الاستدعاء الصحيح
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepo _homeRepo;

  HomeCubit(this._homeRepo) : super(HomeInitial());

  Future<void> fetchProducts() async {
    emit(HomeLoading());
    try {
      final products = await _homeRepo.getProducts();
      emit(HomeLoaded(products));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }
}