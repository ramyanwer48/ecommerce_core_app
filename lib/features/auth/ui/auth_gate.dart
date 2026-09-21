import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/routing/routes.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkGate();
  }

  Future<void> _checkGate() async {
    await Future.delayed(Duration.zero);

    // 1. هل المستخدم مسجل دخول؟
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go(Routes.login);
      return;
    }

    // 2. التحقق من إعدادات البصمة
    final prefs = await SharedPreferences.getInstance();
    final isBiometricEnabled = prefs.getBool('isBiometricEnabled') ?? false;

    if (isBiometricEnabled) {
      bool authenticated = false;
      try {
        authenticated = await _localAuth.authenticate(
          localizedReason: 'قم بتأكيد البصمة للدخول إلى النظام',
        );
      } catch (e) {
        debugPrint("Biometric Error: $e");
      }

      // لو رفض البصمة، تسجيل خروج وتوجيه للوجين
      if (!authenticated) {
        await FirebaseAuth.instance.signOut();
        if (mounted) context.go(Routes.login);
        return;
      }
    }

    // 3. قراءة الصلاحية والتوجيه
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        if (doc.exists) {
          final data = doc.data();
          final String role = data?['role'] ?? 'customer';

          // 👈 التعديل المعماري: الأدمين بيتم توجيهه للمتجر الرئيسي زي العميل العادي
          if (role == 'admin') {
            context.go(Routes.home);
          } else if (role == 'accountant') {
            context.go(Routes.adminOrders);
          } else if (role == 'warehouse') {
            context.go(Routes.home);
          } else {
            context.go(Routes.home);
          }
        } else {
          context.go(Routes.home);
        }
      }
    } catch (e) {
      debugPrint("Firestore Error: $e");
      if (mounted) context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Image.asset(
          'assets/images/splash_screen.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}