import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

class SalesInvoicesScreen extends StatefulWidget {
  const SalesInvoicesScreen({super.key});

  @override
  State<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  String _searchQuery = '';
  String _filterType = 'all'; // all, today, week, month

  Stream<QuerySnapshot> _getSalesStream() {
    // إزالة orderBy لتفادي مشكلة الفايربيز Index
    Query query = FirebaseFirestore.instance.collection('orders');

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
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    return query.snapshots();
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'بدون تاريخ';
    return DateFormat('yyyy-MM-dd • hh:mm a').format(timestamp.toDate());
  }

  String _formatMoney(double amount) {
    return amount.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
  }

  // استخراج اسم العميل بأمان
  String _getCustomerName(Map<String, dynamic> data) {
    String name = '';
    if (data.containsKey('shippingAddress') && data['shippingAddress'] is Map) {
      var addr = data['shippingAddress'];
      name = '${addr['firstName'] ?? ''} ${addr['lastName'] ?? ''}'.trim();
      if (name.isEmpty) name = (addr['name'] ?? addr['fullName'] ?? '').toString().trim();
    }
    if (name.isEmpty) name = (data['userName'] ?? data['customerName'] ?? data['name'] ?? '').toString().trim();
    return name.isEmpty ? 'عميل المتجر' : name;
  }

  // استخراج رقم الهاتف
  String _getPhone(Map<String, dynamic> data) {
    String phone = '';
    if (data.containsKey('shippingAddress') && data['shippingAddress'] is Map) {
      phone = (data['shippingAddress']['phone'] ?? '').toString().trim();
    }
    if (phone.isEmpty) phone = (data['phone'] ?? data['customerPhone'] ?? '').toString().trim();
    return phone;
  }

  // شيت تفاصيل الفاتورة المكتمل
  void _showInvoiceDetails(String orderId, Map<String, dynamic> data) {
    List<dynamic> items = data['items'] ?? [];
    String customerName = _getCustomerName(data);
    String phone = _getPhone(data);
    String status = data['status']?.toString() ?? 'قيد التجهيز';

    // محاولة جلب رقم الأوردر المميز لو موجود
    String displayOrderId = (data['orderNumber'] ?? orderId).toString();
    if (displayOrderId == orderId && orderId.length > 5) {
      displayOrderId = orderId.substring(0, 6).toUpperCase();
    }

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
                            Text('أوردر رقم: $displayOrderId', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                            Text(_formatDate(data['createdAt'] as Timestamp?), style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                          child: Text(status == 'Delivered' || status == 'تم التسليم' ? 'مكتمل' : 'معتمد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 12)),
                        )
                      ],
                    ),
                  ),
                  const Divider(height: 30),

                  // بيانات العميل بتصميم مميز (نفس المشتريات)
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
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('العميل', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                                Text(
                                  customerName,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: brandOrange),
                                ),
                                if (phone.isNotEmpty)
                                  Text(phone, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.black54)),
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
                                Text('${_formatMoney((data['totalPrice'] ?? data['totalAmount'] ?? data['grandTotal'] ?? 0).toDouble())} ج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Align(alignment: Alignment.centerRight, child: Text('الأصناف المباعة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)))),
                  const SizedBox(height: 8),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index] as Map<String, dynamic>;
                        double qty = double.tryParse((item['quantity'] ?? 1).toString()) ?? 1.0;
                        double price = double.tryParse((item['price'] ?? item['unitPrice'] ?? 0).toString()) ?? 0.0;
                        double total = qty * price;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'] ?? item['productName'] ?? 'منتج غير معروف', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('الكمية: ${qty.toInt()}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                                    Text('سعر الوحدة: ${_formatMoney(price)} ج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.teal)),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('إجمالي السطر:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: primaryNavy)),
                                    Text('${_formatMoney(total)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: brandOrange)),
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
          title: const Text('سجل المبيعات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
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
                      hintText: 'ابحث برقم الأوردر أو اسم العميل...',
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
                stream: _getSalesStream(), // 👈 اتعدلت هنا
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: brandOrange));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState('لا توجد فواتير مبيعات.');
                  }

                  var docs = snapshot.data!.docs.toList();

                  // الترتيب المحلي عشان نتفادى مشاكل الفايربيز
                  docs.sort((a, b) {
                    var dataA = a.data() as Map<String, dynamic>;
                    var dataB = b.data() as Map<String, dynamic>;
                    Timestamp? timeA = dataA['createdAt'] as Timestamp?;
                    Timestamp? timeB = dataB['createdAt'] as Timestamp?;
                    if (timeA == null && timeB == null) return 0;
                    if (timeA == null) return 1;
                    if (timeB == null) return -1;
                    return timeB.compareTo(timeA);
                  });

                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      String orderId = doc.id.toLowerCase();
                      String customer = _getCustomerName(data).toLowerCase();
                      String orderNum = (data['orderNumber'] ?? '').toString().toLowerCase();

                      return orderId.contains(_searchQuery) ||
                          customer.contains(_searchQuery) ||
                          orderNum.contains(_searchQuery);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return _buildEmptyState('لم يتم العثور على مبيعات تطابق بحثك.');
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final docId = docs[index].id;

                      String displayOrderId = (data['orderNumber'] ?? docId).toString();
                      if (displayOrderId == docId && docId.length > 5) {
                        displayOrderId = docId.substring(0, 6).toUpperCase();
                      }

                      List items = data['items'] ?? [];
                      double total = double.tryParse((data['totalPrice'] ?? data['totalAmount'] ?? data['grandTotal'] ?? 0).toString()) ?? 0.0;

                      return GestureDetector(
                        onTap: () => _showInvoiceDetails(docId, data),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 3,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.green.shade400.withOpacity(0.5), width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('# $displayOrderId', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy)),
                                    Text(_formatDate(data['createdAt'] as Timestamp?), style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person, size: 20, color: Colors.green.shade600),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                          _getCustomerName(data),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green.shade700)
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                      child: Text('${items.length} أصناف', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                    ),
                                    Text('${_formatMoney(total)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy)),
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
        selectedColor: Colors.green.shade600, // لون مميز للمبيعات
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