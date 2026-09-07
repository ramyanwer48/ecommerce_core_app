import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // تمت إضافة المكتبة لقراءة الذاكرة
import '../../../core/routing/routes.dart';
import '../../../core/theming/colors.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // 1. عرض الشاشة الافتتاحية الأنيقة لمدة ثانيتين
    await Future.delayed(const Duration(seconds: 2));

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // 2. قراءة قرار المستخدم بخصوص البصمة من الذاكرة المحلية
      final prefs = await SharedPreferences.getInstance();
      bool isBiometricEnabled = prefs.getBool('isBiometricEnabled') ?? false;

      if (isBiometricEnabled) {
        // إذا كان قد وافق على التفعيل، نطلب البصمة
        bool authenticated = await _authenticateWithBiometrics();
        if (authenticated) {
          if (mounted) context.go(Routes.home);
        } else {
          // إذا فشلت البصمة، يعود لشاشة تسجيل الدخول
          FirebaseAuth.instance.signOut();
          if (mounted) context.go(Routes.login);
        }
      } else {
        // إذا كان قد رفض تفعيل البصمة، يدخل للمتجر مباشرة بنعومة
        if (mounted) context.go(Routes.home);
      }
    } else {
      if (mounted) context.go(Routes.login);
    }
  }

  Future<bool> _authenticateWithBiometrics() async {
    bool authenticated = false;
    try {
      setState(() { _isAuthenticating = true; });

      authenticated = await auth.authenticate(
        localizedReason: 'الرجاء التحقق من هويتك للدخول إلى متجر رامي',
      );

      setState(() { _isAuthenticating = false; });
      return authenticated;
    } catch (e) {
      debugPrint("خطأ في البصمة: $e");
      setState(() { _isAuthenticating = false; });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsManager.mainDarkBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الشعار الفخم
            const Text(
              'RAMY STORE',
              style: TextStyle(
                  fontSize: 40,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2
              ),
            ),
            const SizedBox(height: 40),

            // التبديل بين شكل التحميل الأنيق وشكل البصمة
            _isAuthenticating
                ? const Column(
              children: [
                Icon(Icons.fingerprint, size: 80, color: ColorsManager.lightBlue),
                SizedBox(height: 20),
                Text('بانتظار البصمة...', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            )
                : const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: ColorsManager.neonBlue,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}