import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice_model.dart'; // 👈 تأكد من المسار الصحيح

class InvoiceRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


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