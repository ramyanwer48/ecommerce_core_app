import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/services/pdf_invoice_service.dart';
import '../../invoices/data/models/invoice_model.dart';

class PurchasesHistoryScreen extends StatefulWidget {
  const PurchasesHistoryScreen({super.key});

  @override
  State<PurchasesHistoryScreen> createState() => _PurchasesHistoryScreenState();
}

class _PurchasesHistoryScreenState extends State<PurchasesHistoryScreen> {
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  String _searchQuery = '';

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedSupplierFilter;
  String? _selectedSourceFilter;

  List<String> _suppliersList = [];

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('suppliers').get();
      setState(() {
        _suppliersList = snap.docs.map((doc) => (doc.data()['name'] ?? '').toString()).where((name) => name.isNotEmpty).toList();
      });
    } catch (e) {
      debugPrint('Error fetching suppliers: $e');
    }
  }

  double _parseSafeDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Stream<QuerySnapshot> _getPurchasesStream() {
    Query query = FirebaseFirestore.instance.collection('purchases').orderBy('date', descending: true);
    if (_startDate != null) query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!));
    if (_endDate != null) {
      DateTime endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }
    return query.snapshots();
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'غير محدد';
    return DateFormat('dd-MM-yyyy • hh:mm a').format(timestamp.toDate());
  }

  String _formatMoney(double amount) {
    final formatter = NumberFormat("#,##0.00", "en_US");
    return formatter.format(amount);
  }

  InvoiceModel _mapToInvoiceModel(Map<String, dynamic> data, String docId) {
    List<dynamic> itemsDynamic = data['items'] ?? [];
    List<InvoiceItemModel> items = itemsDynamic.map((item) {
      return InvoiceItemModel(
        productId: item['productId']?.toString() ?? '',
        productName: item['productName']?.toString() ?? 'صنف غير معروف',
        unitPrice: _parseSafeDouble(item['costPerPiece'] ?? item['price']),
        quantity: int.tryParse(item['quantity'].toString()) ?? 1,
      );
    }).toList();

    return InvoiceModel(
      id: docId,
      invoiceNumber: data['invoiceNumber']?.toString() ?? '',
      partnerId: data['supplierId']?.toString() ?? '',
      partnerName: data['supplierName']?.toString() ?? 'مورد غير معروف',
      type: 'purchase',
      items: items,
      subtotal: _parseSafeDouble(data['totalAmount']),
      totalAmount: _parseSafeDouble(data['totalAmount']),
      date: data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      status: data['status']?.toString() ?? 'paid',
    );
  }

  // 🌟 نافذة اختيار المورد لطباعة كشف الحساب المجمع بأمان تام
  void _showGlobalSupplierStatementModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.only(top: 16, bottom: 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 32),
                    Text('كشف حساب الموردين المجمع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy)),
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black, width: 1.5)),
                      child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black, size: 16), onPressed: () => Navigator.pop(ctx), padding: EdgeInsets.zero),
                    ),
                  ],
                ),
              ),
              const Divider(height: 30),
              Expanded(
                child: _suppliersList.isEmpty
                    ? const Center(child: Text('لا توجد موردين مسجلين', style: TextStyle(fontFamily: 'Cairo')))
                    : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _suppliersList.length,
                  itemBuilder: (context, index) {
                    String sup = _suppliersList[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: Text(sup, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black87)),
                      leading: Icon(Icons.storefront, color: brandOrange),
                      trailing: Icon(Icons.picture_as_pdf_rounded, color: brandOrange),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _generateAndShareSupplierReport(sup);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateAndShareSupplierReport(String supplierName) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator(color: brandOrange)),
      );

      final querySnapshot = await FirebaseFirestore.instance
          .collection('purchases')
          .where('supplierName', isEqualTo: supplierName)
          .get();

      if (!mounted) return;
      Navigator.pop(context); // 🌟 إغلاق اللودينج هنا

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد فواتير مسجلة لهذا المورد', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
        );
        return;
      }

      double totalSum = querySnapshot.docs.fold(0, (sum, doc) => sum + _parseSafeDouble((doc.data() as Map<String, dynamic>)['totalAmount']));
      String title = 'كشف حساب مورد: $supplierName';

      PdfInvoiceService.shareFilteredInvoicesReport(querySnapshot.docs, title, totalSum);

      // 🌟 أضف هذا السطر هنا ليتم إغلاق أي حوار معلق وتختفي الدائرة فوراً
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error generating supplier report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
      );
    }
  }

  void _showSupplierSelectionModal(String? currentSelected, Function(String?) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.only(top: 16, bottom: 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 32),
                    Text('اختر المورد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black, width: 1.5)),
                      child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black, size: 16), onPressed: () => Navigator.pop(ctx), padding: EdgeInsets.zero),
                    ),
                  ],
                ),
              ),
              const Divider(height: 30),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: const Text('جميع الموردين', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      leading: Icon(Icons.all_inclusive, color: primaryNavy),
                      tileColor: currentSelected == null ? brandOrange.withValues(alpha: 0.1) : Colors.transparent,
                      onTap: () { onSelect(null); Navigator.pop(ctx); },
                    ),
                    ..._suppliersList.map((sup) {
                      bool isSelected = sup == currentSelected;
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: Text(sup, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isSelected ? brandOrange : Colors.black)),
                        leading: Icon(Icons.storefront, color: isSelected ? brandOrange : Colors.grey),
                        tileColor: isSelected ? brandOrange.withValues(alpha: 0.1) : Colors.transparent,
                        onTap: () { onSelect(sup); Navigator.pop(ctx); },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    DateTime? tempStart = _startDate;
    DateTime? tempEnd = _endDate;
    String? tempSupplier = _selectedSupplierFilter;
    String? tempSource = _selectedSourceFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 24),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 32),
                      Text('تصفية الفواتير', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black, width: 1.5)),
                        child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black, size: 16), onPressed: () => Navigator.pop(ctx), padding: EdgeInsets.zero),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  Text('الفلترة حسب التاريخ:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 14)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      DateTimeRange? picked = await showDateRangePicker(
                        context: context,
                        initialDateRange: tempStart != null && tempEnd != null ? DateTimeRange(start: tempStart!, end: tempEnd!) : null,
                        firstDate: DateTime(2020), lastDate: DateTime(2100),
                        cancelText: 'إلغاء', confirmText: 'تأكيد',
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              scaffoldBackgroundColor: Colors.white,
                              dialogBackgroundColor: Colors.white,
                              colorScheme: ColorScheme.light(
                                primary: brandOrange,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black87,
                              ),
                              appBarTheme: const AppBarTheme(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                iconTheme: IconThemeData(color: Colors.black87),
                              ),
                            ),
                            child: Directionality(textDirection: TextDirection.rtl, child: child!),
                          );
                        },
                      );
                      if (picked != null) setSheetState(() { tempStart = picked.start; tempEnd = picked.end; });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tempStart != null && tempEnd != null ? '${DateFormat('dd-MM-yyyy').format(tempStart!)}  إلى  ${DateFormat('dd-MM-yyyy').format(tempEnd!)}' : 'تحديد فترة الفواتير (من - إلى)',
                            style: TextStyle(fontFamily: 'Cairo', color: tempStart != null ? primaryNavy : Colors.grey.shade600, fontWeight: FontWeight.bold),
                          ),
                          Icon(Icons.calendar_month_rounded, color: brandOrange),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('الفلترة حسب المورد:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 14)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      _showSupplierSelectionModal(tempSupplier, (selectedVal) { setSheetState(() => tempSupplier = selectedVal); });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              tempSupplier ?? 'جميع الموردين',
                              style: TextStyle(fontFamily: 'Cairo', color: tempSupplier != null ? brandOrange : Colors.grey.shade600, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down, color: primaryNavy),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('الفلترة حسب طريقة الإدخال:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                    child: Row(
                      children: [
                        _buildSegmentButton('الكل', null, tempSource, (val) => setSheetState(() => tempSource = val)),
                        _buildSegmentButton('يدوي', 'manual', tempSource, (val) => setSheetState(() => tempSource = val)),
                        _buildSegmentButton('ذكاء اصطناعي', 'ai', tempSource, (val) => setSheetState(() => tempSource = val)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () {
                            setState(() { _startDate = null; _endDate = null; _selectedSupplierFilter = null; _selectedSourceFilter = null; });
                            Navigator.pop(ctx);
                          },
                          child: const Text('إلغاء الفلتر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: brandOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () {
                            setState(() { _startDate = tempStart; _endDate = tempEnd; _selectedSupplierFilter = tempSupplier; _selectedSourceFilter = tempSource; });
                            Navigator.pop(ctx);
                          },
                          child: const Text('تطبيق الفلتر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSegmentButton(String title, String? value, String? currentValue, Function(String?) onTap) {
    bool isSelected = currentValue == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? brandOrange : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.white : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  void _showInvoiceDetails(Map<String, dynamic> data, String docId) {
    List<dynamic> items = data['items'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(color: Color(0xFFF5F7FA), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: primaryNavy,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: brandOrange, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('فاتورة رقم: ${data['invoiceNumber']}', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: brandOrange), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(_formatDate(data['date'] as Timestamp?), style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'مشاركة الفاتورة',
                        icon: const Icon(Icons.share_rounded, color: Colors.blueGrey),
                        onPressed: () {
                          InvoiceModel invoice = _mapToInvoiceModel(data, docId);
                          PdfInvoiceService.shareInvoicePdf(invoice);
                        },
                      ),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black, width: 1.5)),
                        child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black, size: 16), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: brandOrange.withValues(alpha: 0.5))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('المورد', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
                              Text(data['supplierName'] ?? 'غير معروف', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: brandOrange), overflow: TextOverflow.ellipsis, maxLines: 2),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryNavy,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: brandOrange, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('الإجمالي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold)),
                              Text('${_formatMoney(_parseSafeDouble(data['totalAmount']))} ج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: brandOrange)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(alignment: Alignment.centerRight, child: Text('الأصناف الواردة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16))),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: brandOrange, width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['productName'] ?? 'صنف غير معروف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('الكمية: ${item['quantity']} (الكرتونة: ${item['conversionFactor']})', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
                                  Text('سعر الوحدة: ${_formatMoney(_parseSafeDouble(item['costPerPiece']))} ج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('إجمالي السطر:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: primaryNavy)),
                                  Text('${_formatMoney(_parseSafeDouble(item['totalCost']))} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: brandOrange)),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasFilter = _startDate != null || _endDate != null || _selectedSupplierFilter != null || _selectedSourceFilter != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.white), onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 8),
          ],
          title: const Text('سجل المشتريات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          elevation: 0,
        ),
        body: Column(
          children: [
            Container(
              color: primaryNavy,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'ابحث برقم الفاتورة...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true, fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 🌟 زر كشف الحساب المجمع بلون الهوية (البرتقالي) وتصميم أداة احترافي
                  Tooltip(
                    message: 'كشف حساب الموردين المجمع',
                    child: InkWell(
                      onTap: _showGlobalSupplierStatementModal,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 48, width: 48,
                        decoration: BoxDecoration(
                          color: brandOrange, // لون البرتقالي المتوافق مع الهوية
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  if (hasFilter) ...[
                    InkWell(
                      onTap: () { setState(() { _startDate = null; _endDate = null; _selectedSupplierFilter = null; _selectedSourceFilter = null; }); },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(height: 48, width: 48, decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)), child: Icon(Icons.close_rounded, color: Colors.red.shade700)),
                    ),
                    const SizedBox(width: 8),
                  ],

                  InkWell(
                    onTap: _showFilterSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48, width: 48,
                      decoration: BoxDecoration(
                          color: hasFilter ? brandOrange : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: hasFilter ? brandOrange : Colors.white, width: 1.5)
                      ),
                      child: const Icon(Icons.filter_list_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getPurchasesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState('لا توجد فواتير مشتريات.');

                  var docs = snapshot.data!.docs;

                  docs = docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String invoiceNum = (data['invoiceNumber'] ?? '').toString().toLowerCase();
                    String supplier = (data['supplierName'] ?? '').toString();

                    String source = (data['source'] ?? 'manual').toString();

                    bool matchesSearch = _searchQuery.isEmpty || invoiceNum.contains(_searchQuery);
                    bool matchesSupplier = _selectedSupplierFilter == null || supplier == _selectedSupplierFilter;
                    bool matchesSource = _selectedSourceFilter == null || source == _selectedSourceFilter;

                    return matchesSearch && matchesSupplier && matchesSource;
                  }).toList();

                  if (docs.isEmpty) return _buildEmptyState('لم يتم العثور على فواتير تطابق بحثك أو الفلتر.');

                  double totalSum = docs.fold(0, (sum, doc) => sum + _parseSafeDouble((doc.data() as Map<String, dynamic>)['totalAmount']));

                  return Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(color: primaryNavy, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: primaryNavy.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(hasFilter ? 'الإجمالي في هذه الفترة:' : 'إجمالي جميع الفواتير:', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70)),

                                if (hasFilter && _selectedSupplierFilter != null)
                                  InkWell(
                                    onTap: () {
                                      String title = 'كشف حساب مورد: $_selectedSupplierFilter';
                                      PdfInvoiceService.shareFilteredInvoicesReport(docs, title, totalSum);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(8)),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
                                          SizedBox(width: 4),
                                          Text('طباعة كشف حساب', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                                    child: Text('عدد: ${docs.length}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('${_formatMoney(totalSum)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 32, color: brandOrange)),
                          ],
                        ),
                      ),

                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final docId = docs[index].id;

                            String source = data['source'] ?? 'manual';
                            bool isAi = source == 'ai';

                            return GestureDetector(
                              onTap: () => _showInvoiceDetails(data, docId),
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: brandOrange, width: 1.5)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text('# ${data['invoiceNumber']}', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy), overflow: TextOverflow.ellipsis)),
                                          Directionality(
                                            textDirection: TextDirection.ltr,
                                            child: Text(_formatDate(data['date'] as Timestamp?), style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(color: brandOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.storefront, size: 18, color: brandOrange),
                                              const SizedBox(width: 8),
                                              Flexible(child: Text(data['supplierName'] ?? 'مورد غير معروف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: brandOrange), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 16),
                                      const Divider(height: 1, thickness: 1),
                                      const SizedBox(height: 12),

                                      Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        runSpacing: 8,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                                child: Text('${data['itemCount'] ?? 0} أصناف', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: isAi ? Colors.purple.shade50 : Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                                                child: Text(isAi ? 'الذكاء الاصطناعي' : 'يدوي', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: isAi ? Colors.purple.shade700 : Colors.teal.shade700)),
                                              ),
                                            ],
                                          ),
                                          Text('${_formatMoney(_parseSafeDouble(data['totalAmount']))} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy)),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(fontFamily: 'Cairo', fontSize: 15, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}