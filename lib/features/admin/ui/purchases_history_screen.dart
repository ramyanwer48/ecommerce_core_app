import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

class PurchasesHistoryScreen extends StatefulWidget {
  const PurchasesHistoryScreen({super.key});

  @override
  State<PurchasesHistoryScreen> createState() => _PurchasesHistoryScreenState();
}

class _PurchasesHistoryScreenState extends State<PurchasesHistoryScreen> {
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  String _searchQuery = '';
  String _filterType = 'all'; // all, today, week, month

  Stream<QuerySnapshot> _getPurchasesStream() {
    Query query = FirebaseFirestore.instance.collection('purchases').orderBy('date', descending: true);

    DateTime now = DateTime.now();
    DateTime? startDate;

    if (_filterType == 'today') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (_filterType == 'week') {
      startDate = now.subtract(const Duration(days: 7));
    } else if (_filterType == 'month') {
      startDate = DateTime(now.year, now.month - 1, now.day);
    }

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    return query.snapshots();
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'غير محدد';
    return DateFormat('yyyy-MM-dd • hh:mm a').format(timestamp.toDate());
  }

  String _formatMoney(double amount) {
    return amount.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
  }

  void _showInvoiceDetails(Map<String, dynamic> data) {
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('فاتورة رقم: ${data['invoiceNumber']}', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                            Text(_formatDate(data['date'] as Timestamp?), style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                          child: Text('معتمدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 12)),
                        )
                      ],
                    ),
                  ),
                  const Divider(height: 30),

                  // بيانات المورد بتصميم يظهر الاسم كامل في المنتصف باللون البرتقالي
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: brandOrange.withOpacity(0.5))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center, // توسيط
                              children: [
                                const Text('المورد', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                                Text(
                                  data['supplierName'] ?? 'غير معروف',
                                  textAlign: TextAlign.center, // توسيط
                                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: brandOrange), // لون برتقالي
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: primaryNavy.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryNavy.withOpacity(0.1))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('الإجمالي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                                Text('${_formatMoney((data['totalAmount'] ?? 0).toDouble())} ج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Align(alignment: Alignment.centerRight, child: Text('الأصناف الواردة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)))),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['productName'] ?? 'صنف غير معروف', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('الكمية: ${item['quantity']} (الكرتونة: ${item['conversionFactor']})', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                                    Text('سعر الوحدة: ${_formatMoney((item['costPerPiece'] ?? 0).toDouble())} ج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.teal)),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('إجمالي السطر:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: primaryNavy)),
                                    Text('${_formatMoney((item['totalCost'] ?? 0).toDouble())} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: brandOrange)),
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
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('سجل المشتريات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Column(
          children: [
            Container(
              color: primaryNavy,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'ابحث برقم الفاتورة أو اسم المورد...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل', 'all'),
                        _buildFilterChip('اليوم', 'today'),
                        _buildFilterChip('آخر 7 أيام', 'week'),
                        _buildFilterChip('هذا الشهر', 'month'),
                      ],
                    ),
                  )
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getPurchasesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: brandOrange));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState('لا توجد فواتير مشتريات.');
                  }

                  var docs = snapshot.data!.docs;

                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      String invoiceNum = (data['invoiceNumber'] ?? '').toString().toLowerCase();
                      String supplier = (data['supplierName'] ?? '').toString().toLowerCase();
                      return invoiceNum.contains(_searchQuery) || supplier.contains(_searchQuery);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return _buildEmptyState('لم يتم العثور على فواتير تطابق بحثك.');
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () => _showInvoiceDetails(data),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 16), // مسافة أوسع بين الفواتير
                          elevation: 3,
                          shadowColor: Colors.black26,
                          // 👈 إطار الفاتورة المميز عشان متسيحش في اللي تحتها
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: brandOrange.withOpacity(0.5), width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch, // التمدد بالعرض
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('# ${data['invoiceNumber']}', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy)),
                                    Text(_formatDate(data['date'] as Timestamp?), style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // 👈 اسم المورد في المنتصف باللون البرتقالي
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.storefront, size: 20, color: brandOrange),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                          data['supplierName'] ?? 'مورد غير معروف',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: brandOrange)
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                const Divider(height: 1, thickness: 1),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                          child: Text('${data['itemCount'] ?? 0} أصناف', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                        ),
                                      ],
                                    ),
                                    Text('${_formatMoney((data['totalAmount'] ?? 0).toDouble())} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy)),
                                  ],
                                )
                              ],
                            ),
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

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _filterType == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
        selected: isSelected,
        selectedColor: brandOrange,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
        backgroundColor: Colors.white,
        side: BorderSide.none,
        onSelected: (bool selected) {
          if (selected) setState(() => _filterType = value);
        },
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
          Text(msg, style: TextStyle(fontFamily: 'Cairo', fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}