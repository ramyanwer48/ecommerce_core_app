import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/invoice_model.dart';
import '../data/repos/invoice_repo.dart';

// --- حالات الـ Cubit ---
abstract class InvoiceState {}
class InvoiceInitial extends InvoiceState {}

// 1. حالات إنشاء وحفظ الفاتورة (الخاصة بك القديمة)
class InvoiceLoading extends InvoiceState {}
class InvoiceSuccess extends InvoiceState {
  final InvoiceModel invoice;
  InvoiceSuccess(this.invoice);
}
class InvoiceFailure extends InvoiceState {
  final String error;
  InvoiceFailure(this.error);
}

// 2. 👈 حالات جلب وعرض الفواتير (الجديدة لشاشة الأدمن)
class InvoiceListLoading extends InvoiceState {}
class InvoiceListLoaded extends InvoiceState {
  final List<InvoiceModel> salesInvoices;
  final List<InvoiceModel> purchaseInvoices;
  InvoiceListLoaded(this.salesInvoices, this.purchaseInvoices);
}
class InvoiceListError extends InvoiceState {
  final String error;
  InvoiceListError(this.error);
}

// --- الـ Cubit ---
class InvoiceCubit extends Cubit<InvoiceState> {
  final InvoiceRepo _invoiceRepo;

  InvoiceCubit(this._invoiceRepo) : super(InvoiceInitial());

  // الدالة الخاصة بك (تم الاحتفاظ بها كما هي)

  Future<void> fetchAllInvoices() async {
    emit(InvoiceListLoading());
    try {
      final invoices = await _invoiceRepo.getAllInvoices();

      // تقسيم الفواتير أوتوماتيكياً حسب النوع
      final sales = invoices.where((inv) => inv.type == 'sale').toList();
      final purchases = invoices.where((inv) => inv.type == 'purchase').toList();

      emit(InvoiceListLoaded(sales, purchases));
    } catch (e) {
      emit(InvoiceListError(e.toString()));
    }
  }
}