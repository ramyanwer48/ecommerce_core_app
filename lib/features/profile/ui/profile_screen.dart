import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/routing/routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // دالة تسجيل الخروج الآمن
  Future<void> _logout(BuildContext context) async {
    // 1. تسجيل الخروج من خوادم فايربيز
    await FirebaseAuth.instance.signOut();

    // 2. مسح إعدادات البصمة والتذكر من الذاكرة المحلية
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 3. التوجيه الإجباري لشاشة تسجيل الدخول
    if (context.mounted) {
      context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    // جلب بيانات المستخدم الحالي
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // صورة رمزية للمستخدم
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF00D4FF),
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            // عرض إيميل المستخدم الحقيقي
            Text(
              user?.email ?? 'مستخدم غير معروف',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF000826)),
            ),
            const SizedBox(height: 40),

            // زر سجل الطلبات (تم تعديل الربط هنا)
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Color(0xFF00D4FF)),
              title: const Text('سجل الطلبات', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.white,
              onTap: () {
                // الانتقال الفوري لشاشة سجل الطلبات
                context.push(Routes.orders);
              },
            ),

            const SizedBox(height: 16), // مسافة فاصلة صغيرة
            // زر لوحة الإدارة (مؤقتاً لك كمدير)
            ListTile(
              leading: const Icon(Icons.add_business, color: Colors.green),
              title: const Text('لوحة الإدارة (إضافة منتج)', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.white,
              onTap: () {
                context.push(Routes.addProduct);
              },
            ),
            const Spacer(),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.manage_history, color: Colors.purple),
              title: const Text('إدارة طلبات العملاء', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.white,
              onTap: () {
                context.push(Routes.adminOrders);
              },
            ),

            // زر تسجيل الخروج
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('تسجيل الخروج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                onPressed: () => _logout(context),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}