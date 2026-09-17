import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice_model.dart';

class InvoiceRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createInvoiceAndSyncStock(InvoiceModel invoice) async {
    // استخدام Batch لضمان تنفيذ كل العمليات معاً أو إلغائها معاً (Data Integrity)
    WriteBatch batch = _firestore.batch();

    try {
      // 1. إنشاء مسند (Document) جديد للفاتورة
      DocumentReference invoiceRef = _firestore.collection('invoices').doc();

      // تجهيز الفاتورة بالـ ID الجديد
      InvoiceModel finalInvoice = InvoiceModel(
        id: invoiceRef.id,
        partnerId: invoice.partnerId,
        partnerName: invoice.partnerName,
        type: invoice.type,
        items: invoice.items,
        totalAmount: invoice.totalAmount,
        date: invoice.date,
        status: invoice.status,
      );

      // إضافة أمر حفظ الفاتورة للـ Batch
      batch.set(invoiceRef, finalInvoice.toMap());

      // 2. تحديث المخزون لكل منتج داخل الفاتورة
      for (var item in invoice.items) {
        DocumentReference productRef = _firestore.collection('products').doc(item.productId);

        // لو مبيعات نخصم بالمقدار السالب، لو مشتريات نزود بالمقدار الموجب
        int quantityChange = invoice.type == 'sale' ? -item.quantity : item.quantity;

        // استخدمنا FieldValue.increment عشان لو كذا كاشير بيبيعوا نفس المنتج في نفس اللحظة الداتا ماتضربش
        batch.update(productRef, {
          'stock': FieldValue.increment(quantityChange),
          // لو بتستخدم 'stockQuantity' في الداتا بيز كاسم للحقل، شيل الكومنت من السطر اللي تحت
          // 'stockQuantity': FieldValue.increment(quantityChange),
        });
      }

      // 3. تنفيذ العملية بالكامل
      await batch.commit();

    } catch (e) {
      throw Exception('فشل في حفظ الفاتورة وتحديث المخزون: $e');
    }
  }
}