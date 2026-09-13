import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/address_model.dart';
import '../data/repos/address_repo.dart';

// --- States ---
abstract class AddressState {}

class AddressInitial extends AddressState {}
class AddressLoading extends AddressState {}
class AddressLoaded extends AddressState {
  final List<AddressModel> addresses;
  AddressLoaded(this.addresses);
}
class AddressError extends AddressState {
  final String error;
  AddressError(this.error);
}
class AddressActionSuccess extends AddressState {
  final String message;
  AddressActionSuccess(this.message);
}

// --- Cubit ---
class AddressCubit extends Cubit<AddressState> {
  final AddressRepo _repo;

  AddressCubit(this._repo) : super(AddressInitial());

  // 1. جلب العناوين
  Future<void> fetchAddresses() async {
    emit(AddressLoading());
    try {
      final list = await _repo.getAddresses();
      emit(AddressLoaded(list));
    } catch (e) {
      emit(AddressError(e.toString().replaceAll("Exception: ", "")));
    }
  }

  // 2. إضافة عنوان جديد
  Future<void> addAddress(AddressModel address) async {
    emit(AddressLoading());
    try {
      await _repo.addAddress(address);
      emit(AddressActionSuccess("تم إضافة العنوان بنجاح"));
      await fetchAddresses();
    } catch (e) {
      emit(AddressError(e.toString().replaceAll("Exception: ", "")));
    }
  }

  // 3. تعيين عنوان كافتراضي
  Future<void> setDefaultAddress(String addressId) async {
    try {
      await _repo.setDefaultAddress(addressId);
      await fetchAddresses();
    } catch (e) {
      emit(AddressError(e.toString().replaceAll("Exception: ", "")));
    }
  }

  // 4. حذف عنوان
  Future<void> deleteAddress(String addressId) async {
    try {
      await _repo.deleteAddress(addressId);
      emit(AddressActionSuccess("تم حذف العنوان"));
      await fetchAddresses();
    } catch (e) {
      emit(AddressError(e.toString().replaceAll("Exception: ", "")));
    }
  }
}