import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF0D1B2A);
    final Color brandOrange = Colors.orange.shade600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text(
              'لوحة تحكم الإدارة (ERP Hub)',
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
            bottom: const TabBar(
              indicatorColor: Colors.orange,
              indicatorWeight: 4,
              labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
              unselectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 14),
              tabs: [
                Tab(text: 'إدارة المتجر 🛒', icon: Icon(Icons.storefront_rounded, size: 20)),
                Tab(text: 'المالية والحسابات 💰', icon: Icon(Icons.account_balance_wallet_rounded, size: 20)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              // -----------------------------------------
              // 🛒 التبويب الأول: إدارة المتجر
              // -----------------------------------------
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.95,
                  children: [
                    _buildDashboardCard(
                      context,
                      title: 'المنتجات والمخزون',
                      subtitle: 'الأسعار والكميات',
                      icon: Icons.inventory_2_rounded,
                      color: Colors.orange,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push(Routes.manageProducts);
                      },
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'التصنيفات',
                      subtitle: 'أقسام المتجر',
                      icon: Icons.category_rounded,
                      color: Colors.purple,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push(Routes.manageCategories);
                      },
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'طلبات العملاء',
                      subtitle: 'متابعة الأوردرات',
                      icon: Icons.shopping_bag_rounded,
                      color: Colors.green,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push(Routes.adminOrders);
                      },
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'العملاء والموردين',
                      subtitle: 'الشركاء والحسابات',
                      icon: Icons.handshake_rounded,
                      color: Colors.blue,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push(Routes.partners);
                      },
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'كوبونات الخصم',
                      subtitle: 'العروض والخصومات',
                      icon: Icons.local_offer_rounded,
                      color: Colors.pink,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push(Routes.manageCoupons);
                      },
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'إعلان المتجر',
                      subtitle: 'إدارة البانر والعروض',
                      icon: Icons.campaign_rounded,
                      color: brandOrange,
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        context.push(Routes.adminBanner);
                      },
                    ),
                  ],
                ),
              ),

              // -----------------------------------------
              // 💰 التبويب الثاني: المالية والحسابات
              // -----------------------------------------
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 1. مبيعات
                    _buildWideDashboardCard(
                      context,
                      title: 'إدارة المبيعات وفواتير البيع',
                      subtitle: 'إصدار الفواتير وخصم المخزون وحسابات العملاء',
                      icon: Icons.point_of_sale_rounded,
                      color: Colors.teal.shade700,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push(Routes.createInvoice);
                      },
                    ),
                    const SizedBox(height: 14),

                    // 2. فواتير الشراء (يدوي) - بالمسمى الجديد
                    _buildWideDashboardCard(
                      context,
                      title: 'إدخال فواتير الشراء (يدوي)',
                      subtitle: 'تسجيل بضاعة الموردين وإضافتها للمخزن',
                      icon: Icons.add_shopping_cart_rounded,
                      color: Colors.indigo.shade700,
                      onTap: () {
                        HapticFeedback.lightImpact();
                      },
                    ),
                    const SizedBox(height: 14),

                    // 3. إدخال فواتير الشراء (بالذكاء الاصطناعي) - بالمسمى الجديد
                    _buildWideDashboardCard(
                      context,
                      title: 'إدخال فواتير الشراء (بالذكاء الاصطناعي)',
                      subtitle: 'قراءة صورة الفاتورة أو الـ PDF واستخراج الأصناف تلقائياً',
                      icon: Icons.auto_awesome_rounded,
                      color: Colors.deepPurple,
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('جاري تجهيز محرك الذكاء الاصطناعي لقراءة الفواتير 🤖🚀')),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // 4. السجل اليومي والتقارير (مضبوطة ومريحة تماماً وبدون Overflow)
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.25, // 👈 تم زيادة النسبة لمنع أي Overflow نهائياً
                      children: [
                        _buildDashboardCard(
                          context,
                          title: 'التقارير والأرباح',
                          subtitle: 'قائمة الدخل والأرصدة',
                          icon: Icons.analytics_rounded,
                          color: Colors.blueGrey,
                          onTap: () {
                            HapticFeedback.lightImpact();
                          },
                        ),
                        _buildDashboardCard(
                          context,
                          title: 'السجل اليومي',
                          subtitle: 'حركة النقدية والعمليات',
                          icon: Icons.menu_book_rounded,
                          color: Colors.brown,
                          onTap: () {
                            HapticFeedback.lightImpact();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10), // مسافة أمان إضافية أسفل الشاشة
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideDashboardCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'Cairo'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}