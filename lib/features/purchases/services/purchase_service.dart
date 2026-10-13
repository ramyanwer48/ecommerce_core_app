import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _suppliersCollection = 'suppliers';

  /// دالة ترحيل الفاتورة المعتمدة (تحديث المخزون، تحديث رصيد المورد في جدول الموردين، تسجيل القيود، وأرشفة الفاتورة)
  Future<void> processApprovedInvoice({
    required String supplierName,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required List<Map<String, dynamic>> items,
  }) async {
    WriteBatch batch = _firestore.batch();
    double totalInvoiceAmount = 0.0;
    List<Map<String, dynamic>> archivedItems = [];

    String cleanSupplierName = supplierName.trim().isEmpty
        ? 'مورد عام'
        : supplierName.trim();

    // تحويل التاريخ لصيغة فايربيز لاستخدامه في كل الحركات
    Timestamp firestoreInvoiceDate = Timestamp.fromDate(invoiceDate);

    for (var item in items) {
      String name =
          item['mappedName'] ?? item['rawAiName'] ?? 'Unknown Product';

      // قراءة الكمية والسعر ومعامل التحويل بأمان تام
      int rawQty = item['qty'] is int
          ? item['qty']
          : int.tryParse(item['qty'].toString()) ?? 1;
      double unitPrice = item['price'] is double
          ? item['price']
          : double.tryParse(item['price'].toString()) ?? 0.0;
      int conversionFactor = item['conversionFactor'] is int
          ? item['conversionFactor']
          : int.tryParse(item['conversionFactor'].toString()) ?? 1;
      if (conversionFactor <= 0) conversionFactor = 1;

      // قراءة سعر البيع المحدد من الشاشة
      double sellingPrice = item['sellingPrice'] is double
          ? item['sellingPrice']
          : double.tryParse(item['sellingPrice']?.toString() ?? '') ??
          (unitPrice * 1.25);

      String mainCategory = item['mainCategory'] ?? 'Computers & Systems';
      String subCategory = item['subCategory'] ?? 'Laptops';

      // الحسابات الفعلية للقطع والتكلفة للقطعة الواحدة
      int totalPieces = rawQty * conversionFactor;
      double costPerPiece = unitPrice / conversionFactor;
      double itemTotalCost = rawQty * unitPrice;
      totalInvoiceAmount += itemTotalCost;

      // إنشاء معرف فريد للدفعة الجديدة
      String batchId =
          'batch_${invoiceNumber}_${DateTime.now().millisecondsSinceEpoch}';
      Map<String, dynamic> newBatchData = {
        'batchId': batchId,
        'quantity': totalPieces,
        'costPrice': costPerPiece,
        'supplier': cleanSupplierName,
        'dateAdded': firestoreInvoiceDate,
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

      // قراءة مصفوفة الصور القادمة من شاشة مراجعة الذكاء الاصطناعي
      List<String> imageUrls = [];
      if (item['imageUrls'] != null && item['imageUrls'] is List) {
        imageUrls = List<String>.from(item['imageUrls']);
      }

      String? mappedId = item['mappedId'];

      // البحث الذكي عن المنتج في قاعدة البيانات في حال عدم وجود معرف مسبق
      if (mappedId == null || mappedId.trim().isEmpty) {
        var querySnap = await _firestore
            .collection('products')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();

        if (querySnap.docs.isNotEmpty) {
          mappedId = querySnap.docs.first.id;
        }
      }

      if (mappedId != null && mappedId.isNotEmpty) {
        // صنف مسجل سابقاً: تحديثه وإضافة دفعة جديدة
        DocumentReference productRef =
        _firestore.collection('products').doc(mappedId);

        Map<String, dynamic> updateData = {
          'batches': FieldValue.arrayUnion([newBatchData]),
          'stockQuantity': FieldValue.increment(totalPieces),
          'inStock': true,
          'price': sellingPrice,
        };

        if (imageUrls.isNotEmpty) {
          updateData['imageUrl'] = imageUrls.first;
          updateData['imageUrls'] = FieldValue.arrayUnion(imageUrls);
        }

        batch.update(productRef, updateData);
      } else {
        // صنف جديد كلياً: إنشاء مستند جديد في جدول المنتجات
        DocumentReference newProductRef =
        _firestore.collection('products').doc();
        Map<String, dynamic> newProductData = {
          'name': name,
          'description':
          'Added via purchase invoice #$invoiceNumber from supplier: $cleanSupplierName',
          'price': sellingPrice,
          'costPrice': costPerPiece,
          'category': mainCategory,
          'subCategory': subCategory,
          'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : '',
          'imageUrls': imageUrls,
          'images': [],
          'variations': [],
          'inStock': totalPieces > 0,
          'isActive': false,
          'stockQuantity': totalPieces,
          'batches': [newBatchData],
        };
        batch.set(newProductRef, newProductData);
      }
    }

    // 1. ربط وتحديث رصيد المورد في جدول الموردين الجديد (أو إنشاؤه تلقائياً إن كان جديداً)
    String supplierId = '';
    var supplierSnap = await _firestore
        .collection(_suppliersCollection)
        .where('name', isEqualTo: cleanSupplierName)
        .limit(1)
        .get();

    if (supplierSnap.docs.isNotEmpty) {
      DocumentReference existingSupplierRef = supplierSnap.docs.first.reference;
      supplierId = existingSupplierRef.id;
      batch.update(existingSupplierRef, {
        'balance': FieldValue.increment(-totalInvoiceAmount),
      });
    } else {
      DocumentReference newSupplierRef =
      _firestore.collection(_suppliersCollection).doc();
      supplierId = newSupplierRef.id;
      batch.set(newSupplierRef, {
        'id': supplierId,
        'name': cleanSupplierName,
        'phone': '',
        'type': 'supplier',
        'balance': -totalInvoiceAmount,
        'createdAt': firestoreInvoiceDate,
      });
    }

    // 2. تسجيل القيد المحاسبي المزدوج في دفتر الأستاذ العام
    DocumentReference ledgerRef = _firestore.collection('ledger_entries').doc();

    int numericInvoiceNo =
        int.tryParse(invoiceNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1000;

    Map<String, dynamic> ledgerEntryData = {
      'date': firestoreInvoiceDate,
      'orderId': invoiceNumber,
      'orderNumber': numericInvoiceNo,
      'supplierId': supplierId,
      'supplierName': cleanSupplierName,
      'totalDebit': totalInvoiceAmount,
      'totalCredit': totalInvoiceAmount,
      'entries': [
        {
          'account': 'المخزون',
          'debit': totalInvoiceAmount,
          'credit': 0.0,
        },
        {
          'account': 'المورد: $cleanSupplierName',
          'debit': 0.0,
          'credit': totalInvoiceAmount,
        }
      ],
    };
    batch.set(ledgerRef, ledgerEntryData);

    // 3. أرشفة الفاتورة الأصلية في جدول المشتريات للمراجعة والطباعة
    DocumentReference purchaseInvoiceRef =
    _firestore.collection('purchases').doc();
    Map<String, dynamic> purchaseInvoiceData = {
      'invoiceId': purchaseInvoiceRef.id,
      'invoiceNumber': invoiceNumber,
      'supplierId': supplierId,
      'supplierName': cleanSupplierName,
      'date': firestoreInvoiceDate,
      'totalAmount': totalInvoiceAmount,
      'itemCount': items.length,
      'items': archivedItems,
      'status': 'approved',
    };
    batch.set(purchaseInvoiceRef, purchaseInvoiceData);

    // تنفيذ العملية بالكامل دفعة واحدة
    await batch.commit();
  }
}