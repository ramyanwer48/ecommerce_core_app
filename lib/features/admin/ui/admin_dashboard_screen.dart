import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/routing/routes.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  void _showLowStockSheet(BuildContext context, List<Map<String, dynamic>> lowStockItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
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
                    )
                  ],
                ),
                const SizedBox(height: 8),
                const Text('هذه المنتجات وصلت للحد الأدنى ويجب طلبها من الموردين فوراً.', style: TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo')),
                const Divider(height: 30),
                Expanded(
                  child: ListView.separated(
                    itemCount: lowStockItems.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = lowStockItems[index];
                      final name = item['name'] ?? 'منتج غير معروف';
                      final stock = item['stockQuantity'] ?? 0;
                      final price = item['price'] ?? 0;
                      final isExpensive = (double.tryParse(price.toString()) ?? 0) >= 1500;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade50,
                          child: const Icon(Icons.inventory_2_outlined, color: Colors.red, size: 20),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                        subtitle: Text(isExpensive ? 'منتج غالي (الحد الأدنى 2)' : 'إكسسوار (الحد الأدنى 5)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontFamily: 'Cairo')),
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
        );
      },
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
        drawer: Drawer(
          child: Column(
            children: [
              const UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: primaryNavy),
                accountName: Text('رامي أنور', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                accountEmail: Text('المدير العام (Super Admin)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.orange)),
                currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.admin_panel_settings, size: 40, color: primaryNavy)),
              ),
              ListTile(leading: const Icon(Icons.group_add_rounded, color: Colors.blueGrey), title: const Text('إدارة فريق العمل والصلاحيات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), onTap: () { HapticFeedback.lightImpact(); context.pop(); }),
              ListTile(leading: const Icon(Icons.settings_system_daydream_rounded, color: Colors.blueGrey), title: const Text('إعدادات النظام والنسخ الاحتياطي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), onTap: () { HapticFeedback.lightImpact(); context.pop(); }),
              const Spacer(),
              const Divider(),
              ListTile(leading: const Icon(Icons.exit_to_app_rounded, color: Colors.red), title: const Text('خروج من لوحة التحكم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red)), onTap: () { HapticFeedback.lightImpact(); context.pop(); context.pop(); }),
              const SizedBox(height: 20),
            ],
          ),
        ),
        appBar: AppBar(
          title: const Text('غرفة العمليات (ERP)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
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
                    if (stock <= threshold) {
                      lowStockCount++;
                      lowStockList.add(data);
                    }
                  }
                }

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_active_rounded),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        if (lowStockCount > 0) _showLowStockSheet(context, lowStockList);
                        else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المخزون آمن!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                      },
                    ),
                    if (lowStockCount > 0)
                      Positioned(top: 10, right: 8, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: primaryNavy, width: 2)), child: Text('$lowStockCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                  ],
                );
              },
            ),
            IconButton(icon: const Directionality(textDirection: TextDirection.ltr, child: Icon(Icons.arrow_back)), onPressed: () => context.pop()),
            const SizedBox(width: 4),
          ],
        ),
        body: SingleChildScrollView(
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

                      // 🛠️ الفلترة الدقيقة لحالات الطلب
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
                  // 👈 التعديل تم هنا: ربط الزر بمسار الـ POS مباشرة
                  _buildActionCard(title: 'فاتورة بيع (POS)', subtitle: 'مبيعات مباشرة/كاشير', icon: Icons.point_of_sale_rounded, color: Colors.green.shade600, onTap: () => context.push(Routes.pos)),
                  _buildActionCard(title: 'طلبات أونلاين', subtitle: 'أوردرات المتجر', icon: Icons.shopping_bag_rounded, color: Colors.orange.shade700, onTap: () => context.push(Routes.adminOrders)),
                  _buildActionCard(title: 'سجل المبيعات', subtitle: 'فواتير العملاء السابقة', icon: Icons.receipt_long_rounded, color: Colors.teal.shade600, onTap: () => context.push(Routes.salesInvoices)),
                  _buildActionCard(title: 'حسابات العملاء', subtitle: 'المدينون (العملاء)', icon: Icons.groups_rounded, color: Colors.blueGrey, onTap: () => context.push(Routes.customers)),
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
                  _buildActionCard(title: 'بوالص الشحن', subtitle: 'تتبع وحالات الطرود', icon: Icons.assignment_return_rounded, color: Colors.cyan.shade700, onTap: () => _showComingSoon(context, 'تتبع البوالص')),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('الخزينة والماليات', Icons.account_balance_rounded),
              GridView.count(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.2,
                children: [
                  _buildActionCard(title: 'حركة الخزينة', subtitle: 'الدرج والبنك', icon: Icons.account_balance_wallet_rounded, color: Colors.green.shade800, onTap: () => context.push(Routes.treasury)),
                  _buildActionCard(title: 'الأرباح والخسائر', subtitle: 'تقارير مالية', icon: Icons.trending_up_rounded, color: Colors.deepOrange.shade600, onTap: () => _showComingSoon(context, 'تقارير الأرباح')),
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$featureName (تحت الإنشاء)', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.orange.shade700, duration: const Duration(seconds: 2)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200, width: 1.5)),
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