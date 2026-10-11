import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 📦 دالة ترحيل الفاتورة المعتمدة (تحديث المخزون FIFO، تسجيل القيود، وأرشفة الفاتورة)
  Future<void> processApprovedInvoice({
    required String supplierName,
    required String invoiceNumber,
    required DateTime invoiceDate, // 👈 استقبال تاريخ الفاتورة الفعلي
    required List<Map<String, dynamic>> items,
  }) async {
    WriteBatch batch = _firestore.batch();
    double totalInvoiceAmount = 0.0;
    List<Map<String, dynamic>> archivedItems = [];

    // تحويل التاريخ لصيغة فايربيز لاستخدامه في كل الحركات
    Timestamp firestoreInvoiceDate = Timestamp.fromDate(invoiceDate);

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
        'supplier': supplierName, // 👈 إضافة اسم المورد للدفعة عشان الـ FIFO والمرتجعات
        'dateAdded': firestoreInvoiceDate, // استخدام تاريخ الفاتورة للدفعة
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

      // 👈 قراءة مصفوفة الصور اللي جاية من شاشة مراجعة الذكاء الاصطناعي (بحث جوجل)
      List<String> imageUrls = [];
      if (item['imageUrls'] != null && item['imageUrls'] is List) {
        imageUrls = List<String>.from(item['imageUrls']);
      }

      String? mappedId = item['mappedId'];

      // 🔍 السحر هنا: البحث الذكي عن المنتج في قاعدة البيانات لو مفيش mappedId
      if (mappedId == null || mappedId.trim().isEmpty) {
        var querySnap = await _firestore.collection('products')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();

        if (querySnap.docs.isNotEmpty) {
          mappedId = querySnap.docs.first.id; // تم إيجاد المنتج
        }
      }

      if (mappedId != null && mappedId.isNotEmpty) {
        // 🔗 صنف مسجل سابقاً: تحديثه وإضافة دفعة جديدة (FIFO)
        DocumentReference productRef = _firestore.collection('products').doc(mappedId);

        Map<String, dynamic> updateData = {
          'batches': FieldValue.arrayUnion([newBatchData]), // إضافة الدفعة
          'stockQuantity': FieldValue.increment(totalPieces), // زيادة المخزون
          'inStock': true,
          'price': sellingPrice, // 🚀 تحديث سعر البيع بناءً على التكلفة الجديدة
        };

        // لو المنتج متسجل قبل كده بس من غير صورة، والفاتورة دي جابتله صورة، حدثها
        if (imageUrls.isNotEmpty) {
          updateData['imageUrl'] = imageUrls.first;
          updateData['imageUrls'] = FieldValue.arrayUnion(imageUrls);
        }

        batch.update(productRef, updateData);
      } else {
        // ✨ صنف جديد كلياً: إنشاء مستند جديد في مجموعة products
        DocumentReference newProductRef = _firestore.collection('products').doc();
        Map<String, dynamic> newProductData = {
          'name': name,
          'description': 'Added via purchase invoice #$invoiceNumber from supplier: $supplierName',
          'price': sellingPrice, // السعر اللي حددناه
          'costPrice': costPerPiece,
          'category': mainCategory,
          'subCategory': subCategory,

          // حفظ الصور
          'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : '',
          'imageUrls': imageUrls,
          'images': [],

          'variations': [],
          'inStock': totalPieces > 0,
          'isActive': false, // بينزل مخفي لحد ما تفعله
          'stockQuantity': totalPieces,
          'batches': [newBatchData],
        };
        batch.set(newProductRef, newProductData);
      }
    }

    // 💰 1. تسجيل القيد المحاسبي المزدوج في ledger_entries
    DocumentReference ledgerRef = _firestore.collection('ledger_entries').doc();

    int numericInvoiceNo = int.tryParse(invoiceNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1000;

    Map<String, dynamic> ledgerEntryData = {
      'date': firestoreInvoiceDate,
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
      'date': firestoreInvoiceDate,
      'totalAmount': totalInvoiceAmount,
      'itemCount': items.length,
      'items': archivedItems,
      'status': 'approved',
    };
    batch.set(purchaseInvoiceRef, purchaseInvoiceData);

    // 🚀 تنفيذ العملية بالكامل دفعة واحدة
    await batch.commit();
  }
}