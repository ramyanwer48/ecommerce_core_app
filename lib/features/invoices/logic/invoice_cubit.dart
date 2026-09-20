import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/invoice_model.dart';
import '../data/repos/invoice_repo.dart';

// حالات الـ Cubit
abstract class InvoiceState {}
class InvoiceInitial extends InvoiceState {}
class InvoiceLoading extends InvoiceState {}

// 👈 التعديل هنا: خلينا حالة النجاح تستقبل الفاتورة
class InvoiceSuccess extends InvoiceState {
  final InvoiceModel invoice;
  InvoiceSuccess(this.invoice);
}

class InvoiceFailure extends InvoiceState {
  final String error;
  InvoiceFailure(this.error);
}

class InvoiceCubit extends Cubit<InvoiceState> {
  final InvoiceRepo _invoiceRepo;

  InvoiceCubit(this._invoiceRepo) : super(InvoiceInitial());

  Future<void> saveInvoice(InvoiceModel invoice) async {
    emit(InvoiceLoading());
    try {
      await _invoiceRepo.createInvoiceAndSyncStock(invoice);

      // 👈 التعديل هنا: بنبعت الفاتورة جوه حالة النجاح للشاشة
      emit(InvoiceSuccess(invoice));
    } catch (e) {
      emit(InvoiceFailure(e.toString()));
    }
  }
}