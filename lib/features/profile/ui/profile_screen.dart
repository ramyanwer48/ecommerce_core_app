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
        title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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
              title: const Text('سجل الطلبات', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.white,
              onTap: () => context.push(Routes.orders),
            ),

            const SizedBox(height: 16),

            // زر عناويني المحفوظة (يظهر للجميع)
            ListTile(
              leading: const Icon(Icons.location_on_outlined, color: Color(0xFF007BFF)),
              title: const Text('عناويني المحفوظة', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.white,
              onTap: () => context.push('/addresses'),
            ),

            const SizedBox(height: 16),

            // 🛡️ قسم الإدارة الموحد (يظهر للأدمن فقط ويؤدي لوحة التحكم الشاملة)
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
                          child: Text('صلاحيات الإدارة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Cairo')),
                        ),
                        // 👈 الزر البوابي الوحيد الذي يجمع كل أقسام الإدارة والـ ERP (المنتجات، التصنيفات، الطلبات، الأطراف)
                        ListTile(
                          leading: const Icon(Icons.admin_panel_settings, color: Colors.blueAccent, size: 28),
                          title: const Text('لوحة تحكم الإدارة (ERP Hub)', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                          subtitle: const Text('المنتجات، الطلبات، الأطراف، والموردين', style: TextStyle(fontSize: 12, fontFamily: 'Cairo')),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: Colors.white,
                          onTap: () => context.push(Routes.adminDashboard),
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
                label: const Text('تسجيل الخروج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
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