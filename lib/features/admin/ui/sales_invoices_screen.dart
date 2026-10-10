import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ⚠ تأكد إن مسارات الاستيراد دي مطابقة لمشروعك
import '../../../core/services/pdf_invoice_service.dart';
import '../../invoices/data/models/invoice_model.dart';

class SalesInvoicesScreen extends StatefulWidget {
  const SalesInvoicesScreen({super.key});

  @override
  State<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  String _selectedType = 'All'; // 'All', 'pos', 'online'
  DateTimeRange? _selectedDateRange;

  InvoiceModel _mapToInvoiceModel(Map<String, dynamic> data, String docId, String displayInvoiceNum) {
    List<dynamic> rawItems = data['items'] ?? [];

    List<InvoiceItemModel> items = rawItems.map((i) => InvoiceItemModel(
      productId: i['productId'] ?? i['id'] ?? '',
      productName: i['name'] ?? i['productName'] ?? 'منتج',
      unitPrice: double.tryParse((i['price'] ?? i['unitPrice'] ?? 0).toString()) ?? 0.0,
      quantity: int.tryParse((i['quantity'] ?? 1).toString()) ?? 1,
    )).toList();

    Timestamp? dateTs = data['createdAt'] ?? data['orderDate'] ?? data['date'];

    return InvoiceModel(
      id: docId,
      invoiceNumber: displayInvoiceNum,
      partnerId: data['userId'] ?? data['customerId'] ?? '',
      partnerName: data['customerName'] ?? data['userName'] ?? 'عميل',
      type: 'sale',
      items: items,
      subtotal: double.tryParse((data['subtotal'] ?? 0).toString()) ?? 0.0,
      discountAmount: double.tryParse((data['discountAmount'] ?? 0).toString()) ?? 0.0,
      totalAmount: double.tryParse((data['totalPrice'] ?? data['totalAmount'] ?? 0).toString()) ?? 0.0,
      date: dateTs != null ? dateTs.toDate() : DateTime.now(),
      status: 'paid',
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: AppBarTheme(
              backgroundColor: primaryNavy,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            colorScheme: ColorScheme.light(
              primary: brandOrange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: primaryNavy,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasDateFilter = _selectedDateRange != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
          ],
          title: const Text('سجل فواتير المبيعات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy,
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('تصفية النتائج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                      Row(
                        children: [
                          if (hasDateFilter) ...[
                            InkWell(
                              onTap: () => setState(() => _selectedDateRange = null),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 38,
                                width: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.black87, width: 1.2),
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          InkWell(
                            onTap: () => _pickDateRange(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: hasDateFilter ? brandOrange : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: brandOrange),
                              ),
                              child: Icon(Icons.tune_rounded, color: hasDateFilter ? Colors.white : brandOrange, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل', 'All', Icons.all_inclusive),
                        const SizedBox(width: 8),
                        _buildFilterChip('مقر الشركة', 'pos', Icons.storefront),
                        const SizedBox(width: 8),
                        _buildFilterChip('أونلاين', 'online', Icons.language),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('orders').where('status', isEqualTo: 'Delivered').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primaryNavy));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState('لا توجد فواتير مبيعات مكتملة حتى الآن.');
                  }

                  var rawDocs = snapshot.data!.docs;

                  var filteredDocs = rawDocs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;

                    bool isPos = data['orderType'] == 'pos';
                    if (_selectedType == 'pos' && !isPos) return false;
                    if (_selectedType == 'online' && isPos) return false;

                    if (_selectedDateRange != null) {
                      Timestamp? ts = data['createdAt'] ?? data['orderDate'];
                      if (ts == null) return false;
                      DateTime docDate = ts.toDate();

                      DateTime justDocDate = DateTime(docDate.year, docDate.month, docDate.day);
                      DateTime startDate = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
                      DateTime endDate = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);

                      if (justDocDate.isBefore(startDate) || justDocDate.isAfter(endDate)) {
                        return false;
                      }
                    }
                    return true;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return _buildEmptyState('لا توجد نتائج تطابق خيارات الفلتر.');
                  }

                  filteredDocs.sort((a, b) {
                    Timestamp tA = (a.data() as Map<String, dynamic>)['createdAt'] ?? Timestamp.now();
                    Timestamp tB = (b.data() as Map<String, dynamic>)['createdAt'] ?? Timestamp.now();
                    return tB.compareTo(tA);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      var doc = filteredDocs[index];
                      var data = doc.data() as Map<String, dynamic>;

                      bool isPos = data['orderType'] == 'pos';

                      String displayInvoiceNum = '';
                      if (isPos) {
                        displayInvoiceNum = data['orderNumber']?.toString() ?? 'POS-${doc.id.substring(0, 5)}';
                      } else {
                        int orderNumberInt = data['orderNumber'] ?? 0;
                        Timestamp? dateTs = data['createdAt'] ?? data['orderDate'];
                        DateTime date = dateTs != null ? dateTs.toDate() : DateTime.now();
                        String datePrefix = '${date.year.toString().substring(2)}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

                        displayInvoiceNum = orderNumberInt > 0
                            ? 'ORD-[$datePrefix]-$orderNumberInt'
                            : 'ORD-${doc.id.substring(0, 6).toUpperCase()}';
                      }

                      String customerName = data['customerName'] ?? 'عميل غير معروف';
                      double total = double.tryParse((data['totalPrice'] ?? data['totalAmount'] ?? 0).toString()) ?? 0.0;

                      Timestamp? createdTs = data['createdAt'] ?? data['orderDate'];
                      DateTime dt = createdTs != null ? createdTs.toDate() : DateTime.now();
                      String formattedDate = '${dt.day}/${dt.month}/${dt.year} | ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: brandOrange.withOpacity(0.5), width: 1.5)
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(displayInvoiceNum, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPos ? Colors.blue.shade50 : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isPos ? Colors.blue.shade200 : Colors.green.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(isPos ? Icons.storefront : Icons.language, size: 12, color: isPos ? Colors.blue.shade700 : Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          isPos ? 'الشركة' : 'أونلاين',
                                          style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold, color: isPos ? Colors.blue.shade700 : Colors.green.shade700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  // 👈 إبراز اسم العميل بلون مميز
                                  Expanded(child: Text(customerName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: brandOrange))),
                                  Text('${total.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy)),
                                ],
                              ),
                              const Divider(height: 24, thickness: 0.5),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          InvoiceModel invoice = _mapToInvoiceModel(data, doc.id, displayInvoiceNum);
                                          PdfInvoiceService.shareInvoicePdf(invoice);
                                        },
                                        borderRadius: BorderRadius.circular(50),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                                          child: Icon(Icons.share, size: 20, color: Colors.green.shade700),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      InkWell(
                                        onTap: () {
                                          InvoiceModel invoice = _mapToInvoiceModel(data, doc.id, displayInvoiceNum);
                                          PdfInvoiceService.directPrintInvoice(invoice);
                                        },
                                        borderRadius: BorderRadius.circular(50),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                                          child: Icon(Icons.print, size: 20, color: primaryNavy),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    bool isSelected = _selectedType == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : primaryNavy),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : primaryNavy)),
        ],
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedType = value;
          });
        }
      },
      selectedColor: primaryNavy,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? primaryNavy : Colors.grey.shade300),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}