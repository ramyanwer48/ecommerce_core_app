import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/routing/routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      context.go(Routes.login);
    }
  }

  Future<bool> _checkIfAdmin(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data()?['role'] == 'admin') {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF00D4FF),
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              user?.email ?? 'مستخدم غير معروف',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF000826)),
            ),
            const SizedBox(height: 40),

            // زر سجل الطلبات (يظهر للجميع)
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Color(0xFF00D4FF)),
              title: const Text('سجل الطلبات', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.white,
              onTap: () => context.push(Routes.orders),
            ),

            const SizedBox(height: 16),

            // زر عناويني المحفوظة (يظهر للجميع)
            ListTile(
              leading: const Icon(Icons.location_on_outlined, color: Color(0xFF007BFF)),
              title: const Text('عناويني المحفوظة', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.white,
              onTap: () => context.push('/addresses'),
            ),

            const SizedBox(height: 16),

            // بناء قسم الإدارة بالكامل بناءً على الصلاحيات
            if (user != null)
              FutureBuilder<bool>(
                future: _checkIfAdmin(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  if (snapshot.hasData && snapshot.data == true) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0, right: 8.0),
                          child: Text('صلاحيات الإدارة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                        ListTile(
                          leading: const Icon(Icons.add_business, color: Colors.green),
                          title: const Text('إضافة منتج جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: Colors.white,
                          onTap: () => context.push(Routes.addProduct),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          leading: const Icon(Icons.manage_history, color: Colors.purple),
                          title: const Text('إدارة طلبات العملاء', style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: Colors.white,
                          onTap: () => context.push(Routes.adminOrders),
                        ),
                        const SizedBox(height: 12),
                        // 👈 إدارة المنتجات انحطت هنا جوا صلاحيات الإدارة بس
                        ListTile(
                          leading: const Icon(Icons.inventory, color: Colors.orange),
                          title: const Text('إدارة المنتجات (تعديل/حذف)', style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: Colors.white,
                          onTap: () => context.push(Routes.manageProducts),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

            const SizedBox(height: 32),

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