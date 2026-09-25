import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 📦 دالة ترحيل الفاتورة المعتمدة (تحديث المخزون FIFO، تسجيل القيود، وأرشفة الفاتورة)
  Future<void> processApprovedInvoice({
    required String supplierName,
    required String invoiceNumber,
    required List<Map<String, dynamic>> items,
  }) async {
    WriteBatch batch = _firestore.batch();
    double totalInvoiceAmount = 0.0;
    List<Map<String, dynamic>> archivedItems = [];

    for (var item in items) {
      String name = item['mappedName'] ?? item['rawAiName'] ?? 'Unknown Product';

      // قراءة الكمية والسعر ومعامل التحويل بأمان تام
      int rawQty = item['qty'] is int ? item['qty'] : int.tryParse(item['qty'].toString()) ?? 1;
      double unitPrice = item['price'] is double ? item['price'] : double.tryParse(item['price'].toString()) ?? 0.0;
      int conversionFactor = item['conversionFactor'] is int ? item['conversionFactor'] : int.tryParse(item['conversionFactor'].toString()) ?? 1;
      if (conversionFactor <= 0) conversionFactor = 1;

      // قراءة سعر البيع المحدد من الشاشة
      double sellingPrice = item['sellingPrice'] is double
          ? item['sellingPrice']
          : double.tryParse(item['sellingPrice']?.toString() ?? '') ?? (unitPrice * 1.25);

      String mainCategory = item['mainCategory'] ?? 'Computers & Systems';
      String subCategory = item['subCategory'] ?? 'Laptops';

      // الحسابات الفعلية للقطع والتكلفة للقطعة الواحدة
      int totalPieces = rawQty * conversionFactor;
      double costPerPiece = unitPrice / conversionFactor;
      double itemTotalCost = rawQty * unitPrice; // إجمالي تكلفة السطر
      totalInvoiceAmount += itemTotalCost;

      // إنشاء معرف فريد للدفعة الجديدة (Batch)
      String batchId = 'batch_${invoiceNumber}_${DateTime.now().millisecondsSinceEpoch}';
      Map<String, dynamic> newBatchData = {
        'batchId': batchId,
        'quantity': totalPieces,
        'costPrice': costPerPiece,
        'dateAdded': Timestamp.now(),
      };

      // تجميع بيانات الصنف لأرشفة الفاتورة للطباعة
      archivedItems.add({
        'productName': name,
        'quantity': rawQty,
        'conversionFactor': conversionFactor,
        'totalPieces': totalPieces,
        'unitPrice': unitPrice,
        'costPerPiece': costPerPiece,
        'sellingPrice': sellingPrice,
        'totalCost': itemTotalCost,
        'category': mainCategory,
        'subCategory': subCategory,
      });

      bool isNewProduct = item['isNewProduct'] ?? true;
      String? mappedId = item['mappedId'];

      if (!isNewProduct && mappedId != null && mappedId.isNotEmpty) {
        // 🔗 صنف مسجل سابقاً: إضافة دفعة جديدة (FIFO) وزيادة رصيد المخزن الإجمالي
        DocumentReference productRef = _firestore.collection('products').doc(mappedId);

        batch.update(productRef, {
          'batches': FieldValue.arrayUnion([newBatchData]),
          'stockQuantity': FieldValue.increment(totalPieces),
          'inStock': true,
        });
      } else {
        // ✨ صنف جديد كلياً: إنشاء مستند جديد في مجموعة products
        DocumentReference newProductRef = _firestore.collection('products').doc();
        Map<String, dynamic> newProductData = {
          'name': name,
          'description': 'Added via purchase invoice #$invoiceNumber from supplier: $supplierName',
          'price': sellingPrice, // ✅ سعر البيع المحدد بيدك من الشاشة للجمهور
          'costPrice': costPerPiece,
          'category': mainCategory,
          'subCategory': subCategory,
          'imageUrl': '',
          'images': [],
          'variations': [],
          'inStock': totalPieces > 0,
          'isActive': false, // ✅ مسودة غير مفعلة في المتجر حتى اعتماد الصورة
          'stockQuantity': totalPieces,
          'batches': [newBatchData],
        };
        batch.set(newProductRef, newProductData);
      }
    }

    // 💰 1. تسجيل القيد المحاسبي المزدوج في ledger_entries
    DocumentReference ledgerRef = _firestore.collection('ledger_entries').doc();

    // استخراج رقم صحيح لرقم الفاتورة لتوافق الحقل الرقمي في قاعدة البيانات
    int numericInvoiceNo = int.tryParse(invoiceNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1000;

    Map<String, dynamic> ledgerEntryData = {
      'date': Timestamp.now(),
      'orderId': invoiceNumber,
      'orderNumber': numericInvoiceNo,
      'totalDebit': totalInvoiceAmount,
      'totalCredit': totalInvoiceAmount,
      'entries': [
        {
          'account': 'المخزون',
          'debit': totalInvoiceAmount,
          'credit': 0.0,
        },
        {
          'account': 'المورد: $supplierName',
          'debit': 0.0,
          'credit': totalInvoiceAmount,
        }
      ]
    };
    batch.set(ledgerRef, ledgerEntryData);

    // 📑 2. أرشفة الفاتورة الأصلية في purchases للمراجعة والطباعة
    DocumentReference purchaseInvoiceRef = _firestore.collection('purchases').doc();
    Map<String, dynamic> purchaseInvoiceData = {
      'invoiceId': purchaseInvoiceRef.id,
      'invoiceNumber': invoiceNumber,
      'supplierName': supplierName,
      'date': Timestamp.now(),
      'totalAmount': totalInvoiceAmount,
      'itemCount': items.length,
      'items': archivedItems,
      'status': 'approved',
    };
    batch.set(purchaseInvoiceRef, purchaseInvoiceData);

    // 🚀 تنفيذ العملية بالكامل في فايربيز دفعة واحدة (Atomic Batch Commit)
    await batch.commit();
  }
}