import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/routing/routes.dart';
import '../../../core/di/dependency_injection.dart';

// 👇 استدعاءات الشاشات والـ Cubits المطلوبة
import 'storekeeper_audit_screen.dart';
import 'add_product_screen.dart';
import 'manage_products_screen.dart';
import 'manage_categories_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_coupons_screen.dart';
import 'admin_banner_screen.dart';
import 'manual_purchase_screen.dart';
import 'purchases_history_screen.dart';
import 'sales_invoices_screen.dart';
import 'pos_screen.dart';
import 'inventory_audit_screen.dart';
import 'treasury_screen.dart';
import 'shipping_companies_screen.dart';
import 'waybills_screen.dart';
import '../../purchases/ui/ai_purchase_screen.dart';
import '../../partners/ui/supplier_screen.dart';
import '../../partners/ui/customers_screen.dart';
import '../../partners/ui/partners_management_screen.dart';
import '../../admin/logic/admin_orders_cubit.dart';

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

    if (!mounted) return;
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
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الرفع: $e', style: const TextStyle(fontFamily: 'Cairo'))));
      }
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
                  InkWell(
                    onTap: () { if (Navigator.canPop(ctx)) Navigator.pop(ctx); },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 32, width: 32,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black, width: 2)),
                      child: const Icon(Icons.close, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
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
                  InkWell(
                    onTap: () { if (Navigator.canPop(ctx)) Navigator.pop(ctx); },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 32, width: 32,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black, width: 2)),
                      child: const Icon(Icons.close, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
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

  void _showReconciliationDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ReconciliationBottomSheet(),
    );
  }

  void _showStaffManagementSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const StaffManagementBottomSheet(),
    );
  }

  void _showLowStockSheet(BuildContext context, List<Map<String, dynamic>> lowStockItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 8),
                  const Text('تنبيه نواقص المخزون', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Text('${lowStockItems.length} منتج', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 32, width: 32,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black, width: 2)),
                      child: const Icon(Icons.close, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: lowStockItems.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = lowStockItems[index];
                    final name = item['name'] ?? 'منتج غير معروف';
                    final stock = item['stockQuantity'] ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: Colors.red.shade50, child: const Icon(Icons.inventory_2_outlined, color: Colors.red, size: 20)),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                        child: Text('باقي: $stock', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                      ),
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

  Widget _buildHeaderIcon(IconData icon, Color bgColor, Color iconColor, VoidCallback onTap, {Widget? badge}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          if (badge != null) badge,
        ],
      ),
    );
  }

  Widget _buildPipelineStep({required String title, required IconData icon, required Color color, required String count}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.6), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(count, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo', height: 1.0)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.6), width: 1.5)),
      child: InkWell(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 22, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 26, color: color)),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Color(0xFF0D1B2A), height: 1.2), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 11, fontFamily: 'Cairo', color: Colors.grey.shade600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)
              ]
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
            children: [
              Icon(icon, size: 22, color: const Color(0xFF0D1B2A)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1B2A)))
            ]
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF0D1B2A);
    const Color bgColor = Color(0xFFF5F7FA);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 16, right: 16, bottom: 20),
              decoration: const BoxDecoration(
                color: primaryNavy,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
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

                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('المركز الرئيسي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                        Text('(ERP)', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ],
                    ),
                  ),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                            return _buildHeaderIcon(
                              Icons.notifications_active_rounded,
                              Colors.white.withOpacity(0.1),
                              Colors.white,
                                  () {
                                HapticFeedback.selectionClick();
                                if (lowStockCount > 0) {
                                  _showLowStockSheet(context, lowStockList);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المخزون آمن، لا توجد نواقص', style: TextStyle(fontFamily: 'Cairo'))));
                                }
                              },
                              badge: lowStockCount > 0
                                  ? Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: Text('$lowStockCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                              )
                                  : null,
                            );
                          }
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderIcon(Icons.settings_rounded, Colors.white.withOpacity(0.1), Colors.white, () { HapticFeedback.lightImpact(); _showSystemSettingsSheet(); }),
                      const SizedBox(width: 8),
                      _buildHeaderIcon(Icons.logout_rounded, Colors.red.withOpacity(0.2), Colors.redAccent, () async { HapticFeedback.lightImpact(); await FirebaseAuth.instance.signOut(); if (context.mounted) context.go(Routes.login); }),
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
                            Expanded(child: _buildPipelineStep(title: 'تجهيز', icon: Icons.inventory_rounded, color: Colors.orange.shade700, count: '$preparing')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildPipelineStep(title: 'بوليصة', icon: Icons.print_rounded, color: Colors.lightBlue.shade700, count: '$waybill')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildPipelineStep(title: 'شحن', icon: Icons.local_shipping_rounded, color: Colors.deepPurple.shade500, count: '$shipping')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildPipelineStep(title: 'تسليم', icon: Icons.handshake_rounded, color: Colors.teal.shade600, count: '$delivered')),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    _buildSectionTitle('إدارة المشتريات والموردين', Icons.shopping_cart_checkout_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.1,
                      children: [
                        _buildActionCard(title: 'فاتورة مشتريات ✨', subtitle: 'إدخال بالذكاء الاصطناعي', icon: Icons.document_scanner_rounded, color: Colors.deepPurple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiPurchaseScreen()))),
                        _buildActionCard(title: 'فاتورة مشتريات', subtitle: 'إدخال يدوي', icon: Icons.edit_document, color: Colors.blue.shade700, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualPurchaseScreen()))),
                        _buildActionCard(title: 'سجل المشتريات', subtitle: 'فواتير شراء البضاعة', icon: Icons.history_rounded, color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesHistoryScreen()))),
                        _buildActionCard(title: 'حسابات الموردين', subtitle: 'أرصدة ومديونيات', icon: Icons.store_mall_directory_rounded, color: Colors.brown.shade600, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierScreen()))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle('المبيعات والعملاء', Icons.point_of_sale_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.1,
                      children: [
                        _buildActionCard(title: 'المبيعات المباشرة', subtitle: 'مبيعات المقر/الكاشير', icon: Icons.storefront_rounded, color: Colors.green.shade600, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen()))),
                        _buildActionCard(
                          title: 'طلبات المتجر',
                          subtitle: 'أوردرات الأونلاين',
                          icon: Icons.language_rounded,
                          color: Colors.orange.shade700,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider(create: (context) => getIt<AdminOrdersCubit>()..fetchAllOrders(), child: const AdminOrdersScreen()))),
                        ),
                        _buildActionCard(title: 'فواتير المبيعات', subtitle: 'السجل المجمع (المقر والأونلاين)', icon: Icons.receipt_long_rounded, color: Colors.teal.shade600, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesInvoicesScreen()))),
                        _buildActionCard(title: 'حسابات العملاء', subtitle: 'المدينون وأرصدتهم', icon: Icons.groups_rounded, color: Colors.blueGrey, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen()))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle('المخزن والمنتجات', Icons.inventory_2_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.1,
                      children: [
                        _buildActionCard(title: 'إدارة المنتجات', subtitle: 'إضافة وتسعير', icon: Icons.format_list_bulleted_rounded, color: Colors.amber.shade700, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageProductsScreen()))),
                        _buildActionCard(title: 'التصنيفات والأقسام', subtitle: 'إدارة الهيكلة', icon: Icons.category_rounded, color: Colors.purple.shade600, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()))),
                        _buildActionCard(title: 'إدارة الجرد', subtitle: 'اعتمادات وتوالف', icon: Icons.fact_check_rounded, color: Colors.grey.shade800, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryAuditScreen()))),
                        _buildActionCard(title: 'جرد فعلي', subtitle: 'تجربة جرد الموظف 👁️', icon: Icons.qr_code_scanner, color: Colors.pink.shade400, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorekeeperAuditScreen()))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle('إدارة الشحن والتوصيل', Icons.local_shipping_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.1,
                      children: [
                        _buildActionCard(title: 'شركات الشحن', subtitle: 'حسابات ومستحقات', icon: Icons.directions_car_rounded, color: Colors.lightBlue.shade700, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShippingCompaniesScreen()))),
                        _buildActionCard(title: 'بوالص الشحن', subtitle: 'إسناد وطباعة البوليصة', icon: Icons.receipt_long_rounded, color: Colors.deepPurple.shade600, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaybillsScreen()))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle('الخزينة والماليات والشركاء', Icons.account_balance_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.1,
                      children: [
                        _buildActionCard(title: 'المركز المالي', subtitle: 'الخزينة والأرباح', icon: Icons.account_balance_wallet_rounded, color: Colors.green.shade800, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TreasuryScreen()))),
                        _buildActionCard(title: 'إدارة الشركاء والأرباح', subtitle: 'رأس المال والنسب والتشغيل', icon: Icons.handshake_rounded, color: const Color(0xFF0D1B2A), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PartnersManagementScreen()))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle('واجهة المتجر والعروض', Icons.storefront_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.1,
                      children: [
                        _buildActionCard(title: 'الإعلانات والبانرات', subtitle: 'واجهة التطبيق', icon: Icons.view_carousel_rounded, color: Colors.pink.shade500, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBannerScreen()))),
                        _buildActionCard(title: 'كوبونات الخصم', subtitle: 'إدارة التخفيضات', icon: Icons.local_offer_rounded, color: Colors.redAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCouponsScreen()))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle('الإدارة والصلاحيات والمطابقة', Icons.admin_panel_settings_rounded),
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.1,
                      children: [
                        _buildActionCard(title: 'فريق العمل والصلاحيات', subtitle: 'تخصيص الشاشات للمستخدمين', icon: Icons.group_add_rounded, color: Colors.blueGrey, onTap: () => _showStaffManagementSheet(context)),
                        _buildActionCard(title: 'المطابقة والتدقيق', subtitle: 'فحص العجز والزيادة مالياً', icon: Icons.fact_check_outlined, color: const Color(0xFF00796B), onTap: () => _showReconciliationDialog(context)),
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
}

// ============================================================================
// 🌟 1. الكلاس المسؤول عن نافذة المطابقة
// ============================================================================
class ReconciliationBottomSheet extends StatefulWidget {
  const ReconciliationBottomSheet({super.key});

  @override
  State<ReconciliationBottomSheet> createState() => _ReconciliationBottomSheetState();
}

class _ReconciliationBottomSheetState extends State<ReconciliationBottomSheet> {
  bool isLoading = true;
  double totalSales = 0, totalReceipts = 0, totalCustomerBalance = 0, expectedCash = 0, discrepancy = 0;
  String analysisNote = '';
  String errorMsg = '';

  @override
  void initState() {
    super.initState();
    _fetchReconciliationData();
  }

  Future<void> _fetchReconciliationData() async {
    try {
      var ordersSnap = await FirebaseFirestore.instance.collection('orders').where('status', isNotEqualTo: 'Cancelled').get();
      var ledgerSnap = await FirebaseFirestore.instance.collection('ledger_entries').get();
      var customersSnap = await FirebaseFirestore.instance.collection('customers').get();

      double tSales = 0, tReceipts = 0, tBalance = 0;

      for (var doc in ordersSnap.docs) { tSales += double.tryParse((doc.data()['totalPrice'] ?? doc.data()['totalAmount'] ?? 0).toString()) ?? 0; }
      for (var doc in ledgerSnap.docs) {
        var data = doc.data();
        String type = data['type'] ?? '';
        double amt = double.tryParse((data['amount'] ?? 0).toString()) ?? 0;
        if (type == 'receipt' || type == 'income' || type == 'sale') tReceipts += amt;
      }
      for (var doc in customersSnap.docs) { tBalance += double.tryParse((doc.data()['balance'] ?? 0).toString()) ?? 0; }

      double tExpected = tSales - tBalance;
      double tDiscrepancy = tReceipts - tExpected;
      String tNote = '';

      if (tDiscrepancy.abs() <= 5) {
        tNote = 'الحسابات مسطرة 100%. كل المبيعات إما دخلت الخزينة نقداً أو مسجلة كمديونية على العملاء.';
      } else if (tDiscrepancy < -5) {
        tNote = '🚨 يوجد عجز في الخزينة!\nالمشكلة: في بضاعة طلعت واتسجلت مبيعات، لكن فلوسها لا دخلت الخزينة ولا اتسجلت مديونية على العميل.';
      } else {
        tNote = '⚠️ يوجد زيادة غير مبررة في الخزينة!\nالمشكلة: في فلوس دخلت الدرج ومفيش فاتورة مبيعات تقابلها، أو العميل سدد دينه وإنت نسيت تنزله من رصيده.';
      }

      if (mounted) {
        setState(() {
          totalSales = tSales;
          totalReceipts = tReceipts;
          totalCustomerBalance = tBalance;
          expectedCash = tExpected;
          discrepancy = tDiscrepancy;
          analysisNote = tNote;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMsg = e.toString();
          isLoading = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(discrepancy.abs() <= 5 ? Icons.verified_user_rounded : Icons.warning_rounded, color: discrepancy.abs() <= 5 ? Colors.green : Colors.red, size: 28),
                const SizedBox(width: 8),
                const Text('التدقيق والمطابقة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D1B2A))),
                const Spacer(),
                InkWell(
                  onTap: () { if (Navigator.canPop(context)) Navigator.pop(context); },
                  child: Container(
                    height: 32, width: 32,
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 2)),
                    child: const Icon(Icons.close, color: Colors.black, size: 20),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            if (isLoading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: Color(0xFF0D1B2A))))
            else if (errorMsg.isNotEmpty)
              Padding(padding: const EdgeInsets.all(20), child: Text('حدث خطأ: $errorMsg', style: const TextStyle(fontFamily: 'Cairo', color: Colors.red)))
            else
              Flexible(
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
                        onPressed: () { if (Navigator.canPop(context)) Navigator.pop(context); },
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
    );
  }
}

// ============================================================================
// 🌟 2. الكلاس الخاص بإدارة فريق العمل والصلاحيات (مع الترتيب الذكي للمديرين)
// ============================================================================
class StaffManagementBottomSheet extends StatefulWidget {
  const StaffManagementBottomSheet({super.key});

  @override
  State<StaffManagementBottomSheet> createState() => _StaffManagementBottomSheetState();
}

class _StaffManagementBottomSheetState extends State<StaffManagementBottomSheet> {
  String? selectedUserEmail;
  String? selectedUserName;
  List<String> selectedPermissions = [];
  bool isSaving = false;
  bool isSuperAdmin = false;

  String? flashMessage;
  bool isErrorMsg = false;

  final Map<String, String> _allSystemScreens = {
    'aiPurchase': 'فاتورة مشتريات (AI)', 'manualPurchase': 'فاتورة مشتريات (يدوي)',
    'purchasesHistory': 'سجل المشتريات', 'partners': 'حسابات الموردين',
    'pos': 'المبيعات المباشرة (الكاشير)', 'adminOrders': 'أوردرات الأونلاين',
    'salesInvoices': 'فواتير المبيعات', 'customers': 'حسابات العملاء',
    'manageProducts': 'إدارة المنتجات', 'manageCategories': 'التصنيفات والأقسام',
    'inventoryAudit': 'جرد المخزن', 'shippingCompanies': 'شركات الشحن',
    'waybills': 'بوالص الشحن', 'treasury': 'المركز المالي والخزينة',
    'reconciliation': 'المطابقة والتدقيق', 'adminBanner': 'الإعلانات والبانرات',
    'manageCoupons': 'كوبونات الخصم',
  };

  void _openUserSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('اختر حساب الموظف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D1B2A))),
                  InkWell(
                    onTap: () { Navigator.pop(c); },
                    child: Container(
                      height: 32, width: 32,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black, width: 2)),
                      child: const Icon(Icons.close, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.orange));
                      if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('لا يوجد مستخدمين', style: TextStyle(fontFamily: 'Cairo')));
                      return ListView.builder(
                        itemCount: snap.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = snap.data!.docs[index];
                          String email = (doc.data() as Map)['email'] ?? doc.id;
                          String name = (doc.data() as Map)['name'] ?? email.split('@')[0];
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange.shade300, width: 1.5)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: CircleAvatar(backgroundColor: Colors.orange.shade100, child: Text(name[0].toUpperCase(), style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold))),
                              title: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                              subtitle: Text(email, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54)),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.orange),
                              onTap: () {
                                Navigator.pop(c);
                                _selectUser(email, name);
                              },
                            ),
                          );
                        },
                      );
                    }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectUser(String email, String name) async {
    setState(() {
      selectedUserEmail = email;
      selectedUserName = name;
      selectedPermissions = [];
      isSuperAdmin = false;
      flashMessage = null;
    });
    try {
      var doc = await FirebaseFirestore.instance.collection('staff_roles').doc(email).get();
      if (doc.exists && doc.data() != null) {
        List<dynamic> allowed = doc.data()!['allowedScreens'] ?? [];
        bool adminRole = doc.data()!['isAdmin'] ?? false;
        setState(() {
          selectedPermissions = allowed.map((e) => e.toString()).toList();
          isSuperAdmin = adminRole;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user roles: $e");
    }
  }

  Future<void> _savePermissions() async {
    if (selectedUserEmail == null) {
      setState(() {
        flashMessage = 'يرجى اختيار الموظف أولاً';
        isErrorMsg = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => flashMessage = null);
      });
      return;
    }

    setState(() { isSaving = true; flashMessage = null; });

    try {
      await FirebaseFirestore.instance.collection('staff_roles').doc(selectedUserEmail).set({
        'email': selectedUserEmail,
        'allowedScreens': isSuperAdmin ? _allSystemScreens.keys.toList() : selectedPermissions,
        'isAdmin': isSuperAdmin,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          isSaving = false;
          flashMessage = 'تم حفظ الصلاحيات وتحديث النظام بنجاح ✅';
          isErrorMsg = false;
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSaving = false;
          flashMessage = 'عفواً، حدث خطأ: $e';
          isErrorMsg = true;
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => flashMessage = null);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 16),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إدارة فريق العمل والصلاحيات', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A))),
                      InkWell(
                        onTap: () { if (Navigator.canPop(context)) Navigator.pop(context); },
                        child: Container(
                          height: 32, width: 32,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black, width: 2)),
                          child: const Icon(Icons.close, color: Colors.black, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _openUserSelectionModal,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade400, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))]
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                              child: Icon(Icons.person_search_rounded, color: Colors.blue.shade700, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      selectedUserName ?? 'انقر لاختيار الموظف',
                                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: selectedUserName == null ? 14 : 16, color: selectedUserName == null ? Colors.grey.shade600 : Colors.black87)
                                  ),
                                  if (selectedUserEmail != null)
                                    Text(selectedUserEmail!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (selectedUserEmail != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isSuperAdmin ? Colors.green.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isSuperAdmin ? Colors.green.shade400 : Colors.grey.shade300, width: 1.5),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: const Text('مدير عام (Super Admin)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Text(isSuperAdmin ? 'هذا المستخدم لديه وصول كامل لكل الشاشات' : 'تفعيل لإعطاء صلاحيات كاملة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isSuperAdmin ? Colors.green.shade700 : Colors.grey)),
                          value: isSuperAdmin,
                          activeColor: Colors.green,
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: isSuperAdmin ? Colors.green.shade100 : Colors.grey.shade200, shape: BoxShape.circle),
                            child: Icon(Icons.admin_panel_settings, color: isSuperAdmin ? Colors.green.shade700 : Colors.grey),
                          ),
                          onChanged: (val) {
                            setState(() {
                              isSuperAdmin = val;
                              if (val) {
                                selectedPermissions = _allSystemScreens.keys.toList();
                              } else {
                                selectedPermissions.clear();
                              }
                            });
                          },
                        ),
                      ),

                    Row(
                      children: [
                        Icon(Icons.checklist_rtl_rounded, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text('الشاشات المسموح بها:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange.shade800)),
                        if (isSuperAdmin) const Text(' (مفتوح بالكامل)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Opacity(
                      opacity: isSuperAdmin ? 0.5 : 1.0,
                      child: AbsorbPointer(
                        absorbing: isSuperAdmin,
                        child: Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade300)),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: _allSystemScreens.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (context, index) {
                              String screenKey = _allSystemScreens.keys.elementAt(index);
                              String screenTitle = _allSystemScreens.values.elementAt(index);
                              bool isChecked = selectedPermissions.contains(screenKey);

                              return SwitchListTile(
                                title: Text(screenTitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                                value: isChecked,
                                activeColor: Colors.orange.shade600,
                                onChanged: (val) {
                                  setState(() {
                                    if (val) {
                                      selectedPermissions.add(screenKey);
                                    } else {
                                      selectedPermissions.remove(screenKey);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Text('فريق العمل الحالي:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D1B2A))),
                    const SizedBox(height: 12),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('staff_roles').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد صلاحيات مخصصة حالياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));

                        // 🌟 الترتيب الذكي: المدير العام يظهر في أعلى القائمة دايماً 🌟
                        var docs = snapshot.data!.docs.toList();
                        docs.sort((a, b) {
                          var aData = a.data() as Map<String, dynamic>;
                          var bData = b.data() as Map<String, dynamic>;
                          bool aIsAdmin = aData['isAdmin'] ?? false;
                          bool bIsAdmin = bData['isAdmin'] ?? false;

                          if (aIsAdmin && !bIsAdmin) return -1;
                          if (!aIsAdmin && bIsAdmin) return 1;

                          String aEmail = aData['email'] ?? '';
                          String bEmail = bData['email'] ?? '';
                          return aEmail.compareTo(bEmail);
                        });

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var doc = docs[index];
                            var data = doc.data() as Map<String, dynamic>;
                            List<dynamic> allowedKeys = data['allowedScreens'] ?? [];
                            bool adminRole = data['isAdmin'] ?? false;

                            List<String> arabicScreenNames = allowedKeys.map((key) => _allSystemScreens[key.toString()] ?? '').where((s) => s.isNotEmpty).toList();
                            String screensDisplay = adminRole ? 'كافة الصلاحيات (وصول كامل)' : arabicScreenNames.join('، ');
                            if(screensDisplay.isEmpty) screensDisplay = 'لا يوجد شاشات محددة';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: adminRole ? Colors.green.shade50 : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: adminRole ? Colors.green.shade400 : Colors.grey.shade300, width: 1.5)
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(data['email']?.split('@')[0] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1B2A))),
                                            Text(adminRole ? 'الوظيفة: المدير العام' : 'الوظيفة: موظف نظام', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: adminRole ? Colors.green.shade700 : Colors.blue.shade700, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                                          onPressed: () => FirebaseFirestore.instance.collection('staff_roles').doc(doc.id).delete()
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  const Text('الصلاحيات الممنوحة:', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    screensDisplay,
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: adminRole ? Colors.green.shade800 : Colors.black87, fontWeight: FontWeight.bold, height: 1.6),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (flashMessage != null)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isErrorMsg ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isErrorMsg ? Colors.red.shade300 : Colors.green.shade400, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(isErrorMsg ? Icons.error_outline : Icons.check_circle_outline, color: isErrorMsg ? Colors.red : Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                flashMessage!,
                                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isErrorMsg ? Colors.red.shade800 : Colors.green.shade800, fontSize: 13)
                            ),
                          ),
                        ],
                      ),
                    ),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D1B2A), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: isSaving ? null : _savePermissions,
                    child: isSaving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('حفظ الصلاحيات للموظف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}