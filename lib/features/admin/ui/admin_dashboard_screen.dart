import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/routing/routes.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (currentUser == null) return;
    try {
      var doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          profileImageUrl = doc.data()?['profileImage'];
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  Future<void> _updateProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      String fileName = 'profiles/${currentUser!.uid}.jpg';
      TaskSnapshot snap = await FirebaseStorage.instance.ref(fileName).putFile(File(pickedFile.path));
      String downloadUrl = await snap.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set({
        'profileImage': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => profileImageUrl = downloadUrl);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الصورة بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الرفع: $e', style: const TextStyle(fontFamily: 'Cairo'))));
    }
  }

  void _showUserProfileData() {
    String displayName = currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? 'المدير العام';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('بيانات الحساب والبروفايل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D1B2A))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF0D1B2A), child: Icon(Icons.person, color: Colors.white)),
                title: Text(displayName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('الاسم المسجل بالنظام', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.email, color: Colors.white)),
                title: Text(currentUser?.email ?? 'غير متوفر', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('البريد الإلكتروني للوصول', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
              ),
              const ListTile(
                leading: CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.admin_panel_settings, color: Colors.white)),
                title: Text('مدير عام (Super Admin)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                subtitle: Text('لديك كافة الصلاحيات في النظام', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showSystemSettingsSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings_system_daydream_rounded, color: Color(0xFF0D1B2A)),
                      SizedBox(width: 8),
                      Text('إعدادات ومعلومات النظام', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(height: 20),
              const ListTile(
                leading: Icon(Icons.cloud_done, color: Colors.green),
                title: Text('خوادم قاعدة البيانات (Firebase)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('متصل وتعمل بكفاءة عالية', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.green)),
              ),
              const ListTile(
                leading: Icon(Icons.update, color: Colors.blue),
                title: Text('إصدار النظام الحالي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('ERP Core v2.6.0', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showReconciliationDialog(BuildContext context) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      var ordersSnap = await FirebaseFirestore.instance.collection('orders').where('status', isNotEqualTo: 'Cancelled').get();
      var ledgerSnap = await FirebaseFirestore.instance.collection('ledger_entries').get();
      var customersSnap = await FirebaseFirestore.instance.collection('customers').get();

      double totalSales = 0;
      for (var doc in ordersSnap.docs) { totalSales += double.tryParse((doc.data()['totalPrice'] ?? doc.data()['totalAmount'] ?? 0).toString()) ?? 0; }

      double totalReceipts = 0;
      for (var doc in ledgerSnap.docs) {
        var data = doc.data();
        String type = data['type'] ?? '';
        double amt = double.tryParse((data['amount'] ?? 0).toString()) ?? 0;
        if (type == 'receipt' || type == 'income' || type == 'sale') totalReceipts += amt;
      }

      double totalCustomerBalance = 0;
      for (var doc in customersSnap.docs) { totalCustomerBalance += double.tryParse((doc.data()['balance'] ?? 0).toString()) ?? 0; }

      double expectedCash = totalSales - totalCustomerBalance;
      double discrepancy = totalReceipts - expectedCash;

      String analysisNote = '';
      if (discrepancy.abs() <= 5) {
        analysisNote = 'الحسابات مسطرة 100%. كل المبيعات إما دخلت الخزينة نقداً أو مسجلة كمديونية على العملاء.';
      } else if (discrepancy < -5) {
        analysisNote = '🚨 يوجد عجز في الخزينة!\nالمشكلة: في بضاعة طلعت واتسجلت مبيعات، لكن فلوسها لا دخلت الخزينة ولا اتسجلت مديونية على العميل. (راجع فواتير الآجل اللي متسجلتش في حسابات العملاء).';
      } else if (discrepancy > 5) {
        analysisNote = '⚠️ يوجد زيادة غير مبررة في الخزينة!\nالمشكلة: في فلوس دخلت الدرج ومفيش فاتورة مبيعات تقابلها، أو العميل سدد دينه وإنت نسيت تنزله من رصيده.';
      }

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(discrepancy.abs() <= 5 ? Icons.verified_user_rounded : Icons.warning_rounded, color: discrepancy.abs() <= 5 ? Colors.green : Colors.red, size: 28),
                      const SizedBox(width: 8),
                      const Text('التدقيق والمطابقة المحاسبية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D1B2A))),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: discrepancy.abs() <= 5 ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: discrepancy.abs() <= 5 ? Colors.green.shade200 : Colors.red.shade200)),
                            child: Column(
                              children: [
                                Text(discrepancy.abs() <= 5 ? 'مطابقة ممتازة (0.00)' : 'نتيجة الفحص: ${discrepancy < 0 ? 'عجز في الخزينة' : 'زيادة في الخزينة'}', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: discrepancy.abs() <= 5 ? Colors.green.shade700 : Colors.red.shade700)),
                                const SizedBox(height: 8),
                                Text('${discrepancy.abs().toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 28, color: discrepancy.abs() <= 5 ? Colors.green.shade700 : Colors.red.shade700)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: discrepancy.abs() <= 5 ? Colors.green.shade50 : Colors.amber.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: discrepancy.abs() <= 5 ? Colors.green.shade200 : Colors.amber.shade300)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.lightbulb_outline, color: discrepancy.abs() <= 5 ? Colors.green.shade700 : Colors.brown.shade800, size: 20),
                                    const SizedBox(width: 8),
                                    Text('التشخيص الآلي:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: discrepancy.abs() <= 5 ? Colors.green.shade700 : Colors.brown.shade800)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(analysisNote, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: discrepancy.abs() <= 5 ? Colors.green.shade700 : Colors.brown.shade800, fontWeight: FontWeight.bold, height: 1.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          const Text('تفاصيل المعادلة المحاسبية:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 12),
                          _buildReportRow('1. إجمالي المبيعات', totalSales, Colors.blue.shade700),
                          const SizedBox(height: 4),
                          _buildReportRow('2. يخصم: ديون العملاء (الآجل)', totalCustomerBalance, Colors.orange.shade700, isMinus: true),
                          const Divider(height: 20),
                          _buildReportRow('المفروض يكون في الخزينة (=)', expectedCash, Colors.black87),
                          const SizedBox(height: 12),
                          _buildReportRow('الموجود بالخزينة فعلياً', totalReceipts, Colors.green.shade700),
                          const Divider(height: 24),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D1B2A), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('إغلاق التقرير', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))));
    }
  }

  Widget _buildReportRow(String label, double amount, Color color, {bool isMinus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
        Text('${isMinus ? '-' : ''}${amount.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _showStaffManagementSheet(BuildContext context) {
    String? selectedUserEmail;
    Map<String, bool> permissions = {
      'aiPurchase': false, 'manualPurchase': false, 'purchasesHistory': false, 'partners': false,
      'pos': false, 'adminOrders': false, 'salesInvoices': false, 'customers': false,
      'manageProducts': false, 'manageCategories': false, 'inventoryAudit': false,
      'shippingCompanies': false, 'waybills': false,
      'treasury': false, 'reconciliation': false,
      'adminBanner': false, 'manageCoupons': false,
    };
    Map<String, String> titles = {
      'aiPurchase': 'فاتورة مشتريات (AI)', 'manualPurchase': 'فاتورة مشتريات (يدوي)', 'purchasesHistory': 'سجل المشتريات', 'partners': 'حسابات الموردين',
      'pos': 'المبيعات المباشرة (الكاشير)', 'adminOrders': 'أوردرات الأونلاين', 'salesInvoices': 'فواتير المبيعات', 'customers': 'حسابات العملاء',
      'manageProducts': 'إدارة المنتجات', 'manageCategories': 'التصنيفات والأقسام', 'inventoryAudit': 'جرد المخزن',
      'shippingCompanies': 'شركات الشحن', 'waybills': 'بوالص الشحن',
      'treasury': 'المركز المالي والخزينة', 'reconciliation': 'المطابقة والتدقيق',
      'adminBanner': 'الإعلانات والبانرات', 'manageCoupons': 'كوبونات الخصم',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.90,
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('إدارة فريق العمل والصلاحيات', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A))),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              onTap: () async {
                                showModalBottomSheet(
                                    context: context,
                                    builder: (c) => StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance.collection('users').snapshots(),
                                        builder: (context, snap) {
                                          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                                          if (snap.hasError || !snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('لا يوجد مستخدمين مسجلين', style: TextStyle(fontFamily: 'Cairo')));
                                          var docs = snap.data!.docs;
                                          return ListView.builder(
                                            itemCount: docs.length,
                                            itemBuilder: (context, index) {
                                              String em = (docs[index].data() as Map)['email'] ?? docs[index].id;
                                              return ListTile(
                                                title: Text(em, style: const TextStyle(fontFamily: 'Cairo')),
                                                onTap: () {
                                                  setSheetState(() => selectedUserEmail = em);
                                                  Navigator.pop(c);
                                                },
                                              );
                                            },
                                          );
                                        }
                                    )
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(selectedUserEmail ?? 'اضغط لاختيار إيميل المستخدم', style: TextStyle(fontFamily: 'Cairo', color: selectedUserEmail == null ? Colors.grey : Colors.black, fontWeight: FontWeight.bold)),
                                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('حدد الشاشات المسموح للمستخدم برؤيتها:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                              child: Column(
                                children: permissions.keys.map((key) {
                                  return CheckboxListTile(
                                    title: Text(titles[key]!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                                    value: permissions[key],
                                    activeColor: Colors.orange.shade600,
                                    dense: true,
                                    onChanged: (val) => setSheetState(() => permissions[key] = val!),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D1B2A), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () async {
                                if (selectedUserEmail == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار إيميل أولاً', style: TextStyle(fontFamily: 'Cairo'))));
                                  return;
                                }
                                List<String> allowed = permissions.entries.where((e) => e.value).map((e) => e.key).toList();
                                await FirebaseFirestore.instance.collection('staff_roles').doc(selectedUserEmail).set({
                                  'email': selectedUserEmail,
                                  'allowedScreens': allowed,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));
                                setSheetState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعيين الصلاحيات بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
                              },
                              child: const Text('حفظ وتطبيق الصلاحيات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                            const Divider(height: 30),
                            const Align(alignment: Alignment.centerRight, child: Text('فريق العمل والصلاحيات الحالية:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.grey))),

                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('staff_roles').snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) return const Padding(padding: EdgeInsets.all(8.0), child: Text('لا توجد صلاحيات مخصصة مسجلة بعد.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));
                                if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
                                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.all(8.0), child: Text('لا توجد صلاحيات مخصصة حالياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));

                                var docs = snapshot.data!.docs;
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: docs.length,
                                  itemBuilder: (context, index) {
                                    var doc = docs[index];
                                    var data = doc.data() as Map<String, dynamic>;
                                    List<dynamic> allowed = data['allowedScreens'] ?? [];
                                    return Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                                      child: ListTile(
                                        leading: const CircleAvatar(backgroundColor: Color(0xFF0D1B2A), child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 18)),
                                        title: Text(data['email'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                                        subtitle: Text('مسموح له بـ: ${allowed.length} شاشات', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => FirebaseFirestore.instance.collection('staff_roles').doc(doc.id).delete()),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
      ),
    );
  }

  void _showLowStockSheet(BuildContext context, List<Map<String, dynamic>> lowStockItems) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => Directionality(textDirection: TextDirection.rtl, child: Container(height: MediaQuery.of(context).size.height * 0.65, padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)))), Row(children: [const Icon(Icons.warning_rounded, color: Colors.red, size: 28), const SizedBox(width: 8), const Text('تنبيه نواقص المخزون', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)), child: Text('${lowStockItems.length} منتج', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Cairo')))]), const Divider(height: 30), Expanded(child: ListView.separated(itemCount: lowStockItems.length, separatorBuilder: (context, index) => const Divider(), itemBuilder: (context, index) { final item = lowStockItems[index]; final name = item['name'] ?? 'منتج غير معروف'; final stock = item['stockQuantity'] ?? 0; return ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: Colors.red.shade50, child: const Icon(Icons.inventory_2_outlined, color: Colors.red, size: 20)), title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: Text('باقي: $stock', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')))); } ))]))));
  }

  // 🚀 أداة مساعدة لرسم الأيقونات بحجم "أكبر سِنة" ومريحة للضغط
  Widget _buildHeaderIcon(IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24), // تكبير مساحة التفاعل
      child: Container(
        padding: const EdgeInsets.all(10), // تكبير البادينج سِنة
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 22), // 🚀 تكبير الأيقونة من 18 لـ 22
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF0D1B2A);
    const Color bgColor = Color(0xFFF5F7FA);

    String displayName = currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? 'المدير العام';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
            // 🚀 الهيدر الاحترافي المضغوط بعد شيل الإيميل وتكبير الأيقونات
            Container(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16, right: 16, bottom: 16
              ),
              decoration: const BoxDecoration(
                color: primaryNavy,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('لوحة تحكم (ERP)', style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('products').snapshots(),
                          builder: (context, snapshot) {
                            int lowStockCount = 0;
                            List<Map<String, dynamic>> lowStockList = [];
                            if (snapshot.hasData) {
                              for (var doc in snapshot.data!.docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                double price = double.tryParse(data['price'].toString()) ?? 0;
                                int stock = int.tryParse(data['stockQuantity'].toString()) ?? 0;
                                int threshold = price >= 1500 ? 2 : 5;
                                if (stock <= threshold) { lowStockCount++; lowStockList.add(data); }
                              }
                            }
                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                if (lowStockCount > 0) _showLowStockSheet(context, lowStockList);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: lowStockCount > 0 ? Colors.red.shade600 : Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: lowStockCount > 0
                                      ? [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))]
                                      : [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(lowStockCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: Colors.white, size: 18),
                                    const SizedBox(width: 6),
                                    Text(lowStockCount > 0 ? '$lowStockCount نواقص' : 'المخزون آمن', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                  ],
                                ),
                              ),
                            );
                          }
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _updateProfileImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white,
                              backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
                              child: profileImageUrl == null ? const Icon(Icons.person, size: 30, color: primaryNavy) : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(color: Colors.orange.shade600, shape: BoxShape.circle, border: Border.all(color: primaryNavy, width: 2)),
                              child: const Icon(Icons.camera_alt, size: 10, color: Colors.white),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                            const SizedBox(height: 2),
                            // 🚀 تم إزالة الإيميل ووضع المسمى الوظيفي للحفاظ على الشياكة والمساحة
                            Text('المدير العام', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.orange.shade400)),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 10, // مسافة أوسع شوية بين الأيقونات
                        children: [
                          _buildHeaderIcon(Icons.person_rounded, Colors.white.withOpacity(0.1), Colors.white, () { HapticFeedback.lightImpact(); _showUserProfileData(); }),
                          _buildHeaderIcon(Icons.settings_rounded, Colors.white.withOpacity(0.1), Colors.white, () { HapticFeedback.lightImpact(); _showSystemSettingsSheet(); }),
                          _buildHeaderIcon(Icons.logout_rounded, Colors.red.withOpacity(0.2), Colors.redAccent, () async { HapticFeedback.lightImpact(); await FirebaseAuth.instance.signOut(); if (context.mounted) context.go(Routes.login); }),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle('إحصائيات المخزن (لايف)', Icons.analytics_rounded),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('products').snapshots(),
                      builder: (context, productsSnapshot) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                          builder: (context, categoriesSnapshot) {
                            int totalProducts = 0, activeProducts = 0, inactiveProducts = 0, lowStockCount = 0, totalCategories = 0;
                            if (productsSnapshot.hasData) {
                              totalProducts = productsSnapshot.data!.docs.length;
                              for (var doc in productsSnapshot.data!.docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                bool isActive = data['isActive'] ?? true;
                                double price = double.tryParse(data['price'].toString()) ?? 0;
                                int stock = int.tryParse(data['stockQuantity'].toString()) ?? 0;
                                if (isActive) activeProducts++; else inactiveProducts++;
                                if (stock <= (price >= 1500 ? 2 : 5)) lowStockCount++;
                              }
                            }
                            if (categoriesSnapshot.hasData) totalCategories = categoriesSnapshot.data!.docs.length;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: _buildPipelineStep(title: 'إجمالي', icon: Icons.inventory_2_rounded, color: Colors.blue.shade700, count: '$totalProducts')),
                                const SizedBox(width: 4),
                                Expanded(child: _buildPipelineStep(title: 'نشط', icon: Icons.check_circle_rounded, color: Colors.green, count: '$activeProducts')),
                                const SizedBox(width: 4),
                                Expanded(child: _buildPipelineStep(title: 'غير نشط', icon: Icons.block_rounded, color: Colors.grey.shade600, count: '$inactiveProducts')),
                                const SizedBox(width: 4),
                                Expanded(child: _buildPipelineStep(title: 'أقسام', icon: Icons.category_rounded, color: Colors.purple, count: '$totalCategories')),
                                const SizedBox(width: 4),
                                Expanded(child: _buildPipelineStep(title: 'نواقص', icon: Icons.warning_rounded, color: Colors.red, count: '$lowStockCount')),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('متابعة الطلبات (Pipeline)', Icons.track_changes_rounded),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                      builder: (context, snapshot) {
                        int newOrders = 0, preparing = 0, waybill = 0, shipping = 0, delivered = 0;
                        if (snapshot.hasData) {
                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            String status = data['status']?.toString().toLowerCase() ?? 'new';

                            if (status == 'new' || status == 'جديد' || status == 'pending') newOrders++;
                            else if (status == 'preparing' || status == 'تجهيز' || status == 'processing' || status == 'جاري التجهيز') preparing++;
                            else if (status == 'waybill' || status == 'بوليصة') waybill++;
                            else if (status == 'shipping' || status == 'شحن' || status == 'shipped') shipping++;
                            else if (status == 'delivered' || status == 'تم التسليم' || status == 'completed') delivered++;
                          }
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: _buildPipelineStep(title: 'جديدة', icon: Icons.new_releases_rounded, color: Colors.redAccent, count: '$newOrders')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildPipelineStep(title: 'تجهيز', icon: Icons.inventory_rounded, color: Colors.orange, count: '$preparing')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildPipelineStep(title: 'بوليصة', icon: Icons.print_rounded, color: Colors.lightBlue, count: '$waybill')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildPipelineStep(title: 'شحن', icon: Icons.local_shipping_rounded, color: Colors.deepPurple, count: '$shipping')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildPipelineStep(title: 'تسليم', icon: Icons.handshake_rounded, color: Colors.teal, count: '$delivered')),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle('إدارة المشتريات والموردين', Icons.shopping_cart_checkout_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.2,
                      children: [
                        _buildActionCard(title: 'فاتورة مشتريات ✨', subtitle: 'إدخال بالذكاء الاصطناعي', icon: Icons.document_scanner_rounded, color: Colors.deepPurple, onTap: () => context.push(Routes.aiPurchase)),
                        _buildActionCard(title: 'فاتورة مشتريات', subtitle: 'إدخال يدوي', icon: Icons.edit_document, color: Colors.blue.shade700, onTap: () => context.push(Routes.manualPurchase)),
                        _buildActionCard(title: 'سجل المشتريات', subtitle: 'فواتير شراء البضاعة', icon: Icons.history_rounded, color: Colors.indigo, onTap: () => context.push(Routes.purchasesHistory)),
                        _buildActionCard(title: 'حسابات الموردين', subtitle: 'أرصدة ومديونيات', icon: Icons.store_mall_directory_rounded, color: Colors.brown.shade600, onTap: () => context.push(Routes.partners)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('المبيعات والعملاء', Icons.point_of_sale_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.2,
                      children: [
                        _buildActionCard(title: 'المبيعات المباشرة', subtitle: 'مبيعات المقر/الكاشير', icon: Icons.storefront_rounded, color: Colors.green.shade600, onTap: () => context.push(Routes.pos)),
                        _buildActionCard(title: 'طلبات المتجر', subtitle: 'أوردرات الأونلاين', icon: Icons.language_rounded, color: Colors.orange.shade700, onTap: () => context.push(Routes.adminOrders)),
                        _buildActionCard(title: 'فواتير المبيعات', subtitle: 'السجل المجمع (المقر والأونلاين)', icon: Icons.receipt_long_rounded, color: Colors.teal.shade600, onTap: () => context.push(Routes.salesInvoices)),
                        _buildActionCard(title: 'حسابات العملاء', subtitle: 'المدينون وأرصدتهم', icon: Icons.groups_rounded, color: Colors.blueGrey, onTap: () => context.push(Routes.customers)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('المخزن والمنتجات', Icons.inventory_2_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.2,
                      children: [
                        _buildActionCard(title: 'إدارة المنتجات', subtitle: 'إضافة وتسعير', icon: Icons.format_list_bulleted_rounded, color: Colors.amber.shade700, onTap: () => context.push(Routes.manageProducts)),
                        _buildActionCard(title: 'التصنيفات والأقسام', subtitle: 'إدارة الهيكلة', icon: Icons.category_rounded, color: Colors.purple.shade600, onTap: () => context.push(Routes.manageCategories)),
                        _buildActionCard(title: 'جرد المخزن', subtitle: 'تقارير وتوالف', icon: Icons.fact_check_rounded, color: Colors.grey.shade700, onTap: () => context.push(Routes.inventoryAudit)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('إدارة الشحن والتوصيل', Icons.local_shipping_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.2,
                      children: [
                        _buildActionCard(title: 'شركات الشحن', subtitle: 'حسابات ومستحقات', icon: Icons.directions_car_rounded, color: Colors.lightBlue.shade700, onTap: () => context.push(Routes.shippingCompanies)),
                        _buildActionCard(title: 'بوالص الشحن', subtitle: 'إسناد وطباعة البوليصة', icon: Icons.receipt_long_rounded, color: Colors.deepPurple.shade600, onTap: () => context.push(Routes.waybills)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('الخزينة والماليات', Icons.account_balance_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.2,
                      children: [
                        _buildActionCard(title: 'المركز المالي', subtitle: 'الخزينة والأرباح', icon: Icons.account_balance_wallet_rounded, color: Colors.green.shade800, onTap: () => context.push(Routes.treasury)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('واجهة المتجر والعروض', Icons.storefront_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.2,
                      children: [
                        _buildActionCard(title: 'الإعلانات والبانرات', subtitle: 'واجهة التطبيق', icon: Icons.view_carousel_rounded, color: Colors.pink.shade500, onTap: () => context.push(Routes.adminBanner)),
                        _buildActionCard(title: 'كوبونات الخصم', subtitle: 'إدارة التخفيضات', icon: Icons.local_offer_rounded, color: Colors.redAccent, onTap: () => context.push(Routes.manageCoupons)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('الإدارة والصلاحيات والمطابقة', Icons.admin_panel_settings_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.2,
                      children: [
                        _buildActionCard(
                            title: 'فريق العمل والصلاحيات',
                            subtitle: 'تخصيص الشاشات للمستخدمين',
                            icon: Icons.group_add_rounded,
                            color: Colors.blueGrey,
                            onTap: () => _showStaffManagementSheet(context)
                        ),
                        _buildActionCard(
                            title: 'المطابقة والتدقيق',
                            subtitle: 'فحص العجز والزيادة مالياً',
                            icon: Icons.fact_check_outlined,
                            color: const Color(0xFF00796B),
                            onTap: () => _showReconciliationDialog(context)
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Icon(icon, size: 22, color: const Color(0xFF0D1B2A)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1B2A)))]));
  }

  Widget _buildPipelineStep({required String title, required IconData icon, required Color color, required String count}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3), width: 1.2), boxShadow: [BoxShadow(color: color.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 18), const SizedBox(height: 4), Text(count, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')), const SizedBox(height: 2), Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center, maxLines: 1)]),
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.orange.shade600.withOpacity(0.5), width: 1.5)),
      child: InkWell(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 20, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 22, color: color)), const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Color(0xFF0D1B2A), height: 1.2), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 10, fontFamily: 'Cairo', color: Colors.grey.shade600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)]),
        ),
      ),
    );
  }
}