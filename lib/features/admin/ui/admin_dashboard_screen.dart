import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'لوحة تحكم الإدارة (Admin Hub)',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🌟 1. كارت نظام الفواتير (كبير وممتد بعرض الشاشة لأهميته)
            _buildWideDashboardCard(
              context,
              title: 'نظام الفواتير (بيع وشراء)',
              subtitle: 'إصدار فواتير، خصم المخزون، الحسابات',
              icon: Icons.receipt_long_rounded,
              color: Colors.redAccent.shade700,
              onTap: () => context.push(Routes.createInvoice),
            ),
            const SizedBox(height: 16),

            // 🌟 2. أقسام لوحة التحكم (تم إضافة كوبونات الخصم هنا)
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.88,
              children: [
                _buildDashboardCard(
                  context,
                  title: 'المنتجات والمخزون',
                  subtitle: 'الأسعار والكميات',
                  icon: Icons.inventory_2_rounded,
                  color: Colors.orange,
                  onTap: () => context.push(Routes.manageProducts),
                ),
                _buildDashboardCard(
                  context,
                  title: 'التصنيفات',
                  subtitle: 'أقسام المتجر',
                  icon: Icons.category_rounded,
                  color: Colors.purple,
                  onTap: () => context.push(Routes.manageCategories),
                ),
                _buildDashboardCard(
                  context,
                  title: 'طلبات العملاء',
                  subtitle: 'متابعة الأوردرات',
                  icon: Icons.shopping_bag_rounded,
                  color: Colors.green,
                  onTap: () => context.push(Routes.adminOrders),
                ),
                _buildDashboardCard(
                  context,
                  title: 'العملاء والموردين',
                  subtitle: 'الشركاء والحسابات',
                  icon: Icons.handshake_rounded,
                  color: Colors.blue,
                  onTap: () => context.push(Routes.partners),
                ),
                // 👈 الكارت الجديد الخاص بإدارة الكوبونات
                _buildDashboardCard(
                  context,
                  title: 'كوبونات الخصم',
                  subtitle: 'إدارة العروض والخصومات',
                  icon: Icons.local_offer_rounded,
                  color: Colors.pink,
                  onTap: () => context.push(Routes.manageCoupons),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // تصميم الكارت العريض (للفواتير)
  Widget _buildWideDashboardCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // تصميم الكارت المربع العادي (لباقي الأقسام)
  Widget _buildDashboardCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}