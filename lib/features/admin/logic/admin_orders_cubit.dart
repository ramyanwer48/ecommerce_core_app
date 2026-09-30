import 'package:flutter_bloc/flutter_bloc.dart';
import '../../admin/data/repos/admin_repo.dart';
import '../data/repos/admin_orders_repo.dart';
import 'admin_orders_state.dart';

// 👈 استيراد موديل الطلبات من مسار البروفايل (لحفظ التوافق مع شاشة الأدمن)
import '../../profile/data/models/order_model.dart';

// 👈 استيراد موديل وريبو الفواتير
import '../../invoices/data/models/invoice_model.dart';
import '../../invoices/data/repos/invoice_repo.dart';

class AdminOrdersCubit extends Cubit<AdminOrdersState> {
  final AdminOrdersRepo _ordersRepo;
  final AdminRepo _adminRepo;
  final InvoiceRepo _invoiceRepo; // 👈 إضافة ريبو الفواتير

  AdminOrdersCubit(
      this._ordersRepo,
      this._adminRepo,
      this._invoiceRepo, // 👈 استقبال ريبو الفواتير
      ) : super(AdminOrdersInitial());

  Future<void> fetchAllOrders() async {
    emit(AdminOrdersLoading());
    try {
      final orders = await _ordersRepo.getAllOrders();
      emit(AdminOrdersLoaded(orders));
    } catch (e) {
      emit(AdminOrdersError(e.toString()));
    }
  }

  // 👈 الدالة الآن تستقبل كائن الطلب بالكامل
  Future<void> updateStatus(OrderModel order, String newStatus) async {
    try {
      if (newStatus.toLowerCase() == 'cancelled') {
        await _adminRepo.updateOrderStatusAndRestoreStock(
          orderId: order.id,
          newStatus: newStatus,
        );
      } else {
        // تحديث حالة الطلب في قاعدة البيانات
        await _ordersRepo.updateOrderStatus(order.id, newStatus);

        // ==========================================
        // 👈 الأتمتة: إنشاء فاتورة بيع عند التسليم
        // ==========================================
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

  // 👈 دالة خاصة ومخفية (Private Function) لإنشاء الفاتورة أوتوماتيكياً
  Future<void> _generateAndSaveInvoiceForDeliveredOrder(OrderModel order) async {
    try {
      // 1. تجهيز بيانات عناصر الفاتورة من الطلب
      final List<InvoiceItemModel> invoiceItems = order.items.map((item) => InvoiceItemModel(
        productId: item.productId ?? '',
        productName: item.name,
        unitPrice: item.unitPrice,
        quantity: item.quantity,
      )).toList();

      // 2. إنشاء رقم الفاتورة (مطابق لطريقة الشاشة)
      final String datePrefix = '${order.date.year.toString().substring(2)}${order.date.month.toString().padLeft(2, '0')}${order.date.day.toString().padLeft(2, '0')}';
      final String displayOrderNumber = order.orderNumber > 0
          ? 'ORD-$datePrefix-${order.orderNumber}'
          : 'ORD-${order.id.substring(0, order.id.length > 6 ? 6 : order.id.length).toUpperCase()}';

      // 3. بناء الفاتورة
      final invoice = InvoiceModel(
        id: 'INV-${order.id}',
        invoiceNumber: displayOrderNumber,
        orderId: order.id,
        partnerId: order.userId,
        partnerName: order.phone,
        type: 'sale', // 👈 تحديد أنها فاتورة بيع
        items: invoiceItems,
        subtotal: order.subtotal,
        discountAmount: order.discountAmount,
        totalAmount: order.totalPrice,
        date: DateTime.now(),
        status: 'paid',
      );

      // 4. حفظ الفاتورة في Firestore
      await _invoiceRepo.createInvoiceAndSyncStock(invoice);

    } catch (e) {
      print('Error generating auto-invoice: $e');
    }
  }
}