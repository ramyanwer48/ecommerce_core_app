abstract class AddProductState {}
class AddProductInitial extends AddProductState {}
class AddProductLoading extends AddProductState {}
class AddProductSuccess extends AddProductState {}
class AddProductError extends AddProductState {
  final String error;
  AddProductError(this.error);
}