import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersArchiveScreen extends StatefulWidget {
  const OrdersArchiveScreen({super.key});

  @override
  State<OrdersArchiveScreen> createState() => _OrdersArchiveScreenState();
}

class _OrdersArchiveScreenState extends State<OrdersArchiveScreen> {
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;
  String _searchQuery = '';

  Future<void> _restoreOrderToActive(BuildContext context, String orderId) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'Processing',
      });

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Text('تم الاسترجاع بنجاح', style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
              ],
            ),
            content: const Text(
              'تم إرجاع الطلب إلى قائمة الطلبات الجارية بنجاح.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black87),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext); // إغلاق الديالوج
                  Navigator.pop(context); // الرجوع لشاشة الطلبات الجارية لتحديثها فوراً
                },
                child: const Text('حسناً', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الاسترجاع: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
      );
    }
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    String lower = status.toLowerCase();
    if (lower.contains('deliver')) {
      return {'text': 'تم التوصيل (مؤرشف)', 'color': Colors.green};
    } else if (lower.contains('cancel')) {
      return {'text': 'ملغي (مؤرشف)', 'color': Colors.red};
    }
    return {'text': status, 'color': Colors.grey};
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
          ],
          title: const Text(
            'أرشيف الطلبات المكتملة والملغية',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Cairo',
              fontSize: 16,
            ),
          ),
          centerTitle: true,
          backgroundColor: primaryNavy,
        ),
        body: Column(
          children: [
            Container(
              color: primaryNavy,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ابحث في الأرشيف (رقم الأوردر أو الهاتف)...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: brandOrange));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'الأرشيف فارغ تماماً',
                        style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String status = (data['status'] ?? '').toString().toLowerCase();
                    return status.contains('deliver') || status.contains('cancel');
                  }).toList();

                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      String phone = (data['phone'] ?? '').toString().toLowerCase();
                      String id = doc.id.toLowerCase();
                      return phone.contains(_searchQuery) || id.contains(_searchQuery);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد طلبات في الأرشيف حتى الآن',
                        style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      String status = data['status'] ?? 'Pending';
                      var statusConfig = _getStatusConfig(status);
                      double totalPrice = (data['totalPrice'] ?? data['totalSellingAmount'] ?? 0.0).toDouble();
                      String phone = data['phone'] ?? '';
                      String address = data['address'] ?? '';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: statusConfig['color'].withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'أوردر رقم: #${doc.id.substring(0, 6).toUpperCase()}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryNavy),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusConfig['color'].withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      statusConfig['text'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: statusConfig['color'],
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.phone_iphone_rounded, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(address, style: const TextStyle(fontSize: 13, color: Colors.black54, fontFamily: 'Cairo')),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'الإجمالي: ${totalPrice.toStringAsFixed(2)} ج.م',
                                    style: TextStyle(color: brandOrange, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryNavy,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.restore, size: 16, color: Colors.white),
                                    label: const Text(
                                      'إعادة للطلبات الجارية',
                                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => _restoreOrderToActive(context, doc.id),
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
}