import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF0D1B2A);
    const Color bgColor = Color(0xFFF4F6F9);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,

        // -------------------------------------------------------------
        // القائمة الجانبية (Drawer) لصلاحيات الإدارة العليا
        // -------------------------------------------------------------
        drawer: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: primaryNavy),
                accountName: const Text('رامي أنور', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                accountEmail: const Text('المدير العام (Super Admin)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.orange)),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.admin_panel_settings, size: 40, color: primaryNavy),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.group_add_rounded, color: Colors.blueGrey),
                title: const Text('إدارة فريق العمل والصلاحيات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_system_daydream_rounded, color: Colors.blueGrey),
                title: const Text('إعدادات النظام والنسخ الاحتياطي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                },
              ),
              const Spacer(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
                title: const Text('خروج من لوحة التحكم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red)),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop(); // يغلق القائمة
                  context.pop(); // يرجع للصفحة الرئيسية
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // -------------------------------------------------------------
        // الـ AppBar (تم إضافة زرار الـ Drawer الافتراضي)
        // -------------------------------------------------------------
        appBar: AppBar(
          title: const Text(
            'غرفة تحكم المتجر (ERP)',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Directionality(
                textDirection: TextDirection.ltr,
                child: const Icon(Icons.arrow_back),
              ),
              onPressed: () => context.pop(),
            ),
            const SizedBox(width: 8),
          ],
        ),

        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // 1. شريط الأوردرات الحي (بدون سكرول - Fit to screen)
              // ==========================================
              const Text(
                'متابعة التشغيل الحي (Live Pipeline)',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildPipelineStep(context, title: 'جديدة', icon: Icons.new_releases_rounded, color: Colors.redAccent, count: '3')),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPipelineStep(context, title: 'بالمخزن', icon: Icons.inventory_rounded, color: Colors.orange, count: '5')),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPipelineStep(context, title: 'البوليصة', icon: Icons.print_rounded, color: Colors.blue, count: '2')),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPipelineStep(context, title: 'في الطريق', icon: Icons.local_shipping_rounded, color: Colors.purple, count: '1')),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPipelineStep(context, title: 'تم التسليم', icon: Icons.check_circle_rounded, color: Colors.green, count: '12')),
                ],
              ),
              const SizedBox(height: 30),

              // ==========================================
              // 2. كروت دورة المتجر الأساسية (الـ 6 كروت)
              // ==========================================
              const Text(
                'دورة عمل المتجر (الأنظمة المركزية)',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.15,
                children: [
                  _buildMacroCard(
                    context,
                    title: 'المشتريات والموردين',
                    icon: Icons.add_shopping_cart_rounded,
                    color: Colors.indigo.shade600,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showSubMenu(context, title: 'المشتريات والموردين', items: [
                        _SubMenuItem(
                          title: 'إدخال فاتورة المشتريات بالذكاء الاصطناعي',
                          icon: Icons.auto_awesome,
                          color: Colors.deepPurple,
                          onTap: () => context.push(Routes.aiPurchase), // 👈 تم الربط هنا
                        ),
                        _SubMenuItem(
                          title: 'إدخال فاتورة المشتريات (يدوي)',
                          icon: Icons.edit_document,
                          color: Colors.blue,
                          onTap: () {},
                        ),
                        _SubMenuItem(
                          title: 'حسابات الموردين',
                          icon: Icons.local_shipping_outlined,
                          color: Colors.brown,
                          onTap: () => context.push(Routes.partners),
                        ),
                      ]);
                    },
                  ),
                  _buildMacroCard(
                    context,
                    title: 'المخازن والمنتجات',
                    icon: Icons.inventory_2_rounded,
                    color: Colors.orange.shade700,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showSubMenu(context, title: 'المخازن والمنتجات', items: [
                        _SubMenuItem(title: 'إدارة المنتجات والتسعير', icon: Icons.format_list_bulleted, color: Colors.orange, onTap: () => context.push(Routes.manageProducts)),
                        _SubMenuItem(title: 'إدارة التصنيفات والأقسام', icon: Icons.category, color: Colors.purple, onTap: () => context.push(Routes.manageCategories)),
                      ]);
                    },
                  ),
                  _buildMacroCard(
                    context,
                    title: 'واجهة المتجر والعروض',
                    icon: Icons.storefront_rounded,
                    color: Colors.teal.shade600,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showSubMenu(context, title: 'واجهة المتجر والعروض', items: [
                        _SubMenuItem(title: 'إعلان المتجر (البانر)', icon: Icons.campaign, color: Colors.orange, onTap: () => context.push(Routes.adminBanner)),
                        _SubMenuItem(title: 'كوبونات الخصم', icon: Icons.local_offer, color: Colors.pink, onTap: () => context.push(Routes.manageCoupons)),
                      ]);
                    },
                  ),
                  _buildMacroCard(
                    context,
                    title: 'المبيعات والطلبات',
                    icon: Icons.point_of_sale_rounded,
                    color: Colors.blue.shade700,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showSubMenu(context, title: 'المبيعات والطلبات', items: [
                        _SubMenuItem(title: 'طلبات الأونلاين (العملاء)', icon: Icons.shopping_bag, color: Colors.green, onTap: () => context.push(Routes.adminOrders)),
                        _SubMenuItem(title: 'إصدار فاتورة بيع مباشر', icon: Icons.receipt_long, color: Colors.teal, onTap: () => context.push(Routes.createInvoice)),
                      ]);
                    },
                  ),
                  _buildMacroCard(
                    context,
                    title: 'حسابات العملاء',
                    icon: Icons.groups_rounded,
                    color: Colors.blueGrey,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push(Routes.partners);
                    },
                  ),
                  _buildMacroCard(
                    context,
                    title: 'الخزينة والماليات',
                    icon: Icons.account_balance_wallet_rounded,
                    color: Colors.amber.shade700,
                    onTap: () {
                      HapticFeedback.lightImpact();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // دوال بناء واجهة المستخدم
  // -----------------------------------------------------------------

  Widget _buildPipelineStep(BuildContext context, {required String title, required IconData icon, required Color color, required String count}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 20),
              Positioned(
                top: -6,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text(count, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMacroCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, color.withOpacity(0.05)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Color(0xFF0D1B2A)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // دالة القائمة المنبثقة (تم تعديل الخطوط لتلائم سطر واحد)
  // -----------------------------------------------------------------
  void _showSubMenu(BuildContext context, {required String title, required List<_SubMenuItem> items}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                ...items.map((item) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  leading: CircleAvatar(
                    backgroundColor: item.color.withOpacity(0.1),
                    child: Icon(item.icon, color: item.color, size: 20), // 👈 تصغير الأيقونة قليلاً
                  ),
                  // 👈 تصغير الخط هنا ليصبح 13 لضمان بقائه في سطر واحد
                  title: Text(item.title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    context.pop();
                    item.onTap();
                  },
                )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SubMenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _SubMenuItem({required this.title, required this.icon, required this.color, required this.onTap});
}