import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShippingCompaniesScreen extends StatefulWidget {
  const ShippingCompaniesScreen({super.key});

  @override
  State<ShippingCompaniesScreen> createState() => _ShippingCompaniesScreenState();
}

class _ShippingCompaniesScreenState extends State<ShippingCompaniesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  String _searchQuery = '';

  // الشاشة السفلية لإضافة جهة الشحن (BottomSheet)
  void _showAddCourierSheet() {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController phoneCtrl = TextEditingController();
    TextEditingController feeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),

                Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, color: primaryNavy, size: 28),
                    const SizedBox(width: 12),
                    Text('إضافة جهة شحن جديدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم الشركة / المندوب',
                    labelStyle: const TextStyle(fontFamily: 'Cairo'),
                    filled: true, fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: Icon(Icons.business, color: primaryNavy),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف للتواصل',
                    labelStyle: const TextStyle(fontFamily: 'Cairo'),
                    filled: true, fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: Icon(Icons.phone, color: primaryNavy),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'تكلفة الشحن الافتراضية (ج.م)',
                    labelStyle: const TextStyle(fontFamily: 'Cairo'),
                    filled: true, fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: brandOrange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        onPressed: () async {
                          String name = nameCtrl.text.trim();
                          String phone = phoneCtrl.text.trim();
                          double defaultFee = double.tryParse(feeCtrl.text) ?? 0.0;
                          String currentUserId = _auth.currentUser?.uid ?? '';

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برجاء إدخال اسم الشركة أو المندوب أولاً', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                            return;
                          }

                          // إظهار اللودينج
                          showDialog(context: context, barrierDismissible: false, builder: (loadingCtx) => const Center(child: CircularProgressIndicator()));

                          try {
                            await _firestore.collection('couriers').add({
                              'name': name,
                              'phone': phone,
                              'defaultFee': defaultFee,
                              'isActive': true,
                              'userId': currentUserId,
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            if (mounted) {
                              Navigator.pop(context); // إغلاق اللودينج
                              Navigator.pop(sheetCtx); // إغلاق الشاشة السفلية
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة جهة الشحن بنجاح 🚀', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.pop(context); // إغلاق اللودينج فقط، وترك الشاشة السفلية مفتوحة
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('تم الرفض من قواعد أمان الفايربيز (Rules)! برجاء السماح لجدول couriers', style: const TextStyle(fontFamily: 'Cairo')),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 5)
                              ));
                            }
                          }
                        },
                        child: const Text('حفظ البيانات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('شركات الشحن والمندوبين', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: brandOrange,
          onPressed: _showAddCourierSheet,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('إضافة مندوب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        body: Column(
          children: [
            Container(
              color: primaryNavy,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ابحث عن اسم الشركة أو المندوب...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('couriers').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
                  if (snapshot.hasError) {
                    return const Center(child: Text('غير مسموح بقراءة البيانات، تأكد من الـ Rules', style: TextStyle(fontFamily: 'Cairo', color: Colors.red)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_filled_rounded, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('لا توجد جهات شحن مسجلة بعد', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs;
                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data['name'] ?? '').toString().toLowerCase().contains(_searchQuery);
                    }).toList();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      String docId = docs[index].id;
                      String name = data['name'] ?? 'غير معروف';
                      String phone = data['phone'] ?? 'لا يوجد رقم';
                      double fee = double.tryParse((data['defaultFee'] ?? 0).toString()) ?? 0.0;
                      bool isActive = data['isActive'] ?? true;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: isActive ? Colors.blue.shade50 : Colors.grey.shade200,
                            radius: 25,
                            child: Icon(Icons.local_shipping_rounded, color: isActive ? Colors.blue.shade700 : Colors.grey),
                          ),
                          title: Text(name, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, decoration: isActive ? null : TextDecoration.lineThrough)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(phone, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.attach_money, size: 14, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text('تسعيرة الشحن: $fee ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          trailing: Switch(
                            value: isActive,
                            activeColor: brandOrange,
                            onChanged: (val) {
                              _firestore.collection('couriers').doc(docId).update({'isActive': val});
                            },
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