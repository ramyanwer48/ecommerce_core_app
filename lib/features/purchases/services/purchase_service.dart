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
    String source = 'manual', // 🌟 خليناها اختيارية عشان ما تضربش إيرور في الشاشات القديمة
  }) async {
    WriteBatch batch = _firestore.batch();
    double totalInvoiceAmount = 0.0;
    List<Map<String, dynamic>> archivedItems = [];

    String cleanSupplierName = supplierName.trim().isEmpty ? 'مورد عام' : supplierName.trim();
    Timestamp firestoreInvoiceDate = Timestamp.fromDate(invoiceDate);

    for (var item in items) {
      String name = item['mappedName'] ?? item['rawAiName'] ?? 'Unknown Product';
      int rawQty = item['qty'] is int ? item['qty'] : int.tryParse(item['qty'].toString()) ?? 1;
      double unitPrice = item['price'] is double ? item['price'] : double.tryParse(item['price'].toString()) ?? 0.0;
      int conversionFactor = item['conversionFactor'] is int ? item['conversionFactor'] : int.tryParse(item['conversionFactor'].toString()) ?? 1;
      if (conversionFactor <= 0) conversionFactor = 1;

      double sellingPrice = item['sellingPrice'] is double ? item['sellingPrice'] : double.tryParse(item['sellingPrice']?.toString() ?? '') ?? (unitPrice * 1.25);
      String mainCategory = item['mainCategory'] ?? 'Computers & Systems';
      String subCategory = item['subCategory'] ?? 'Laptops';

      int totalPieces = rawQty * conversionFactor;
      double costPerPiece = unitPrice / conversionFactor;
      double itemTotalCost = rawQty * unitPrice;
      totalInvoiceAmount += itemTotalCost;

      String batchId = 'batch_${invoiceNumber}_${DateTime.now().millisecondsSinceEpoch}';
      Map<String, dynamic> newBatchData = {
        'batchId': batchId, 'quantity': totalPieces, 'costPrice': costPerPiece,
        'supplier': cleanSupplierName, 'dateAdded': firestoreInvoiceDate,
      };

      archivedItems.add({
        'productName': name, 'quantity': rawQty, 'conversionFactor': conversionFactor,
        'totalPieces': totalPieces, 'unitPrice': unitPrice, 'costPerPiece': costPerPiece,
        'sellingPrice': sellingPrice, 'totalCost': itemTotalCost, 'category': mainCategory, 'subCategory': subCategory,
      });

      List<String> imageUrls = [];
      if (item['imageUrls'] != null && item['imageUrls'] is List) imageUrls = List<String>.from(item['imageUrls']);

      String? mappedId = item['mappedId'];
      if (mappedId == null || mappedId.trim().isEmpty) {
        var querySnap = await _firestore.collection('products').where('name', isEqualTo: name).limit(1).get();
        if (querySnap.docs.isNotEmpty) mappedId = querySnap.docs.first.id;
      }

      if (mappedId != null && mappedId.isNotEmpty) {
        DocumentReference productRef = _firestore.collection('products').doc(mappedId);
        Map<String, dynamic> updateData = {
          'batches': FieldValue.arrayUnion([newBatchData]),
          'stockQuantity': FieldValue.increment(totalPieces),
          'inStock': true, 'price': sellingPrice,
        };
        if (imageUrls.isNotEmpty) {
          updateData['imageUrl'] = imageUrls.first;
          updateData['imageUrls'] = FieldValue.arrayUnion(imageUrls);
        }
        batch.update(productRef, updateData);
      } else {
        DocumentReference newProductRef = _firestore.collection('products').doc();
        batch.set(newProductRef, {
          'name': name,
          'description': 'Added via purchase invoice #$invoiceNumber from supplier: $cleanSupplierName',
          'price': sellingPrice, 'costPrice': costPerPiece, 'category': mainCategory, 'subCategory': subCategory,
          'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : '', 'imageUrls': imageUrls,
          'images': [], 'variations': [], 'inStock': totalPieces > 0, 'isActive': false, 'stockQuantity': totalPieces,
          'batches': [newBatchData],
        });
      }
    }

    String supplierId = '';
    var supplierSnap = await _firestore.collection(_suppliersCollection).where('name', isEqualTo: cleanSupplierName).limit(1).get();
    if (supplierSnap.docs.isNotEmpty) {
      DocumentReference existingSupplierRef = supplierSnap.docs.first.reference;
      supplierId = existingSupplierRef.id;
      batch.update(existingSupplierRef, {'balance': FieldValue.increment(-totalInvoiceAmount)});
    } else {
      DocumentReference newSupplierRef = _firestore.collection(_suppliersCollection).doc();
      supplierId = newSupplierRef.id;
      batch.set(newSupplierRef, {'id': supplierId, 'name': cleanSupplierName, 'phone': '', 'type': 'supplier', 'balance': -totalInvoiceAmount, 'createdAt': firestoreInvoiceDate});
    }

    DocumentReference ledgerRef = _firestore.collection('ledger_entries').doc();
    int numericInvoiceNo = int.tryParse(invoiceNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1000;
    batch.set(ledgerRef, {
      'date': firestoreInvoiceDate, 'orderId': invoiceNumber, 'orderNumber': numericInvoiceNo,
      'supplierId': supplierId, 'supplierName': cleanSupplierName, 'totalDebit': totalInvoiceAmount, 'totalCredit': totalInvoiceAmount,
      'entries': [
        {'account': 'المخزون', 'debit': totalInvoiceAmount, 'credit': 0.0},
        {'account': 'المورد: $cleanSupplierName', 'debit': 0.0, 'credit': totalInvoiceAmount}
      ],
    });

    DocumentReference purchaseInvoiceRef = _firestore.collection('purchases').doc();
    batch.set(purchaseInvoiceRef, {
      'invoiceId': purchaseInvoiceRef.id, 'invoiceNumber': invoiceNumber, 'supplierId': supplierId,
      'supplierName': cleanSupplierName, 'date': firestoreInvoiceDate, 'totalAmount': totalInvoiceAmount,
      'itemCount': items.length, 'items': archivedItems, 'status': 'approved',
      'source': source, // 🌟 هنا بيتم حفظ المصدر في الفايربيز
    });

    await batch.commit();
  }
}