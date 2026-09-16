import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // خلفية هادئة واحترافية
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2, // كارتين جنب بعض
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.88, // جعل الكروت مستطيلة وأطول لتملى الشاشة بشكل فخم ومنسق
          children: [
            // 1. المنتجات والمخزون
            _buildDashboardCard(
              context,
              title: 'المنتجات والمخزون',
              subtitle: 'الأسعار والكميات',
              icon: Icons.inventory_2_rounded,
              color: Colors.orange,
              onTap: () => context.push(Routes.manageProducts),
            ),

            // 2. التصنيفات
            _buildDashboardCard(
              context,
              title: 'التصنيفات',
              subtitle: 'أقسام المتجر',
              icon: Icons.category_rounded,
              color: Colors.purple,
              onTap: () => context.push(Routes.manageCategories),
            ),

            // 3. طلبات العملاء
            _buildDashboardCard(
              context,
              title: 'طلبات العملاء',
              subtitle: 'متابعة الأوردرات',
              icon: Icons.shopping_bag_rounded,
              color: Colors.green,
              onTap: () => context.push(Routes.adminOrders),
            ),

            // 4. العملاء والموردين (ERP)
            _buildDashboardCard(
              context,
              title: 'العملاء والموردين',
              subtitle: 'الشركاء والحسابات',
              icon: Icons.handshake_rounded,
              color: Colors.blue,
              onTap: () => context.push(Routes.partners),
            ),
          ],
        ),
      ),
    );
  }

  // تصميم الكارت الفخم الواسع
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
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}