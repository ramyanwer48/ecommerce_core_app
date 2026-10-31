import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/repos/admin_returns_repo.dart';

class ReturnsLogScreen extends StatefulWidget {
  const ReturnsLogScreen({super.key});

  @override
  State<ReturnsLogScreen> createState() => _ReturnsLogScreenState();
}

class _ReturnsLogScreenState extends State<ReturnsLogScreen> {
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = const Color(0xFFFF9F0A);
  final AdminReturnsRepo _repo = AdminReturnsRepo();

  bool _isLoading = true;
  List _completedReturns = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLog();
  }

  Future<void> _fetchLog() async {
    try {
      final result = await _repo.getCompletedReturnsLog();
      setState(() {
        _completedReturns = result as List;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('سجل المرتجعات الأرشيفي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo', fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          elevation: 0,
          automaticallyImplyLeading: false, // إلغاء السهم التلقائي على اليمين
          actions: [
            // 🚀 نقل زر الرجوع ليصبح في أقصى الشمال (اليسار) وبنفس اتجاهه
            Directionality(
              textDirection: TextDirection.ltr,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: brandOrange))
            : _error != null
            ? Center(child: Text('خطأ: $_error', style: const TextStyle(fontFamily: 'Cairo', color: Colors.red)))
            : _completedReturns.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('لا يوجد سجل مرتجعات سابقة', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ],
          ),
        )
            : ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _completedReturns.length,
          itemBuilder: (context, index) {
            Map data = _completedReturns[index] as Map;
            return _buildLogCard(data);
          },
        ),
      ),
    );
  }

  Widget _buildLogCard(Map data) {
    final String orderNumber = data['orderNumber']?.toString() ?? 'غير متوفر';
    final String status = data['status']?.toString() ?? 'Approved';
    final double totalRefund = (data['totalRefund'] ?? 0.0).toDouble();
    final String reason = data['reason']?.toString() ?? 'بدون سبب';

    bool isApproved = status == 'Approved';

    String formattedDate = '';
    if (data['requestDate'] != null) {
      DateTime date = (data['requestDate'] as Timestamp).toDate();
      formattedDate = '\u200E${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }

    final List items = (data['items'] ?? []) as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isApproved ? Colors.green.shade300 : Colors.red.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isApproved ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isApproved ? 'معتمد ومسترد' : 'مرفوض',
                    style: TextStyle(color: isApproved ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Cairo'),
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.black54, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1, color: Color(0xFFEEEEEE)),
            Text('رقم الطلب: #$orderNumber', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
            const SizedBox(height: 8),
            Text('السبب: $reason', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 12),
            const Text('الأصناف في الطلب:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            ...items.map((item) {
              Map itemMap = item as Map;
              String name = itemMap['name']?.toString() ?? 'منتج';
              int qty = (itemMap['quantity'] ?? 1).toInt();
              double price = (itemMap['price'] ?? 0.0).toDouble();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('- $name (الكمية: $qty)', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                    Text('${(price * qty).toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54), textDirection: TextDirection.ltr),
                  ],
                ),
              );
            }).toList(),
            const Divider(height: 20, thickness: 1, color: Color(0xFFEEEEEE)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إجمالي المبلغ المسترد:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                Text('${totalRefund.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade700), textDirection: TextDirection.ltr),
              ],
            ),
          ],
        ),
      ),
    );
  }
}