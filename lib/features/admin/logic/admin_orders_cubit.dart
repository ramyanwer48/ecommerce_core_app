import 'package:flutter_bloc/flutter_bloc.dart';
import '../../admin/data/repos/admin_repo.dart';
import '../data/repos/admin_orders_repo.dart';
import 'admin_orders_state.dart';

// استيراد موديل الطلبات
import '../../profile/data/models/order_model.dart';
// استيراد موديل وريبو الفواتير
import '../../invoices/data/models/invoice_model.dart';
import '../../invoices/data/repos/invoice_repo.dart';

class AdminOrdersCubit extends Cubit<AdminOrdersState> {
  final AdminOrdersRepo _ordersRepo;
  final AdminRepo _adminRepo;
  final InvoiceRepo _invoiceRepo;

  AdminOrdersCubit(
      this._ordersRepo,
      this._adminRepo,
      this._invoiceRepo,
      ) : super(AdminOrdersInitial());

  Future<void> fetchAllOrders() async {
    emit(AdminOrdersLoading());
    try {
      final orders = await _ordersRepo.getAllOrders();

      // 🚀 التعديل هنا: ترتيب الطلبات بحيث يظهر الأحدث في أعلى القائمة دائماً
      orders.sort((a, b) => b.date.compareTo(a.date));

      emit(AdminOrdersLoaded(orders));
    } catch (e) {
      emit(AdminOrdersError(e.toString()));
    }
  }

  Future<void> updateStatus(OrderModel order, String newStatus) async {
    try {
      if (newStatus.toLowerCase() == 'cancelled') {
        await _adminRepo.updateOrderStatusAndRestoreStock(
          orderId: order.id,
          newStatus: newStatus,
        );
      } else {
        await _ordersRepo.updateOrderStatus(order.id, newStatus);

        if (newStatus == 'Delivered') {
          await _generateAndSaveInvoiceForDeliveredOrder(order);
        }
      }

      emit(AdminOrderStatusUpdated());
      fetchAllOrders();
    } catch (e) {
      emit(AdminOrdersError(e.toString()));
    }
  }

  Future<void> _generateAndSaveInvoiceForDeliveredOrder(OrderModel order) async {
    try {
      final List<InvoiceItemModel> invoiceItems = order.items.map((item) => InvoiceItemModel(
        productId: item.productId ?? '',
        productName: item.name,
        unitPrice: item.unitPrice,
        quantity: item.quantity,
      )).toList();

      final String datePrefix = '${order.date.year.toString().substring(2)}${order.date.month.toString().padLeft(2, '0')}${order.date.day.toString().padLeft(2, '0')}';
      final String displayOrderNumber = order.orderNumber > 0
          ? 'ORD-$datePrefix-${order.orderNumber}'
          : 'ORD-${order.id.substring(0, order.id.length > 6 ? 6 : order.id.length).toUpperCase()}';

      final invoice = InvoiceModel(
        id: 'INV-${order.id}',
        invoiceNumber: displayOrderNumber,
        orderId: order.id,
        partnerId: order.userId,
        partnerName: order.phone,
        type: 'sale',
        items: invoiceItems,
        subtotal: order.subtotal,
        discountAmount: order.discountAmount,
        totalAmount: order.totalPrice,
        date: DateTime.now(),
        status: 'paid',
      );

      // ⚠ التعديل هنا: تم إيقاف دالة الحفظ القديمة التي تم حذفها
      // سيتم ربط هذا الجزء لاحقاً بخدمة (CheckoutRepo) لتطبيق الـ FIFO في المبيعات!
      // await _invoiceRepo.createInvoiceAndSyncStock(invoice);

      print('تم تجهيز بيانات الفاتورة بنجاح: ${invoice.invoiceNumber} (في انتظار ربطها بخدمة المبيعات الجديدة)');

    } catch (e) {
      print('Error generating auto-invoice: $e');
    }
  }
}