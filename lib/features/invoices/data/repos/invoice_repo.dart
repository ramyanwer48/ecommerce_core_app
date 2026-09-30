import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice_model.dart'; // 👈 تأكد من المسار الصحيح

class InvoiceRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createInvoiceAndSyncStock(InvoiceModel invoice) async {
    // استخدام Batch لضمان تنفيذ كل العمليات معاً أو إلغائها معاً (Data Integrity)
    WriteBatch batch = _firestore.batch();

    try {
      // 1. إنشاء مسند (Document) جديد للفاتورة
      DocumentReference invoiceRef = _firestore.collection('invoices').doc();

      // 👈 التعديل هنا: تمرير الحقول الجديدة (رقم الفاتورة، الإجمالي الفرعي، الخصم، الخ)
      InvoiceModel finalInvoice = InvoiceModel(
        id: invoiceRef.id,
        invoiceNumber: invoice.invoiceNumber,
        orderId: invoice.orderId,
        partnerId: invoice.partnerId,
        partnerName: invoice.partnerName,
        type: invoice.type,
        items: invoice.items,
        subtotal: invoice.subtotal,
        discountAmount: invoice.discountAmount,
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
          // 'stockQuantity': FieldValue.increment(quantityChange), // لو ده اسم الحقل عندك
        });
      }

      // 3. تنفيذ العملية بالكامل
      await batch.commit();

    } catch (e) {
      throw Exception('فشل في حفظ الفاتورة وتحديث المخزون: $e');
    }
  }

  // ==========================================
  // 👈 الإضافة الجديدة: دالة جلب جميع الفواتير
  // ==========================================
  Future<List<InvoiceModel>> getAllInvoices() async {
    try {
      final snapshot = await _firestore
          .collection('invoices')
          .orderBy('date', descending: true) // من الأحدث للأقدم
          .get();

      return snapshot.docs.map((doc) => InvoiceModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('فشل في جلب الفواتير: $e');
    }
  }
}