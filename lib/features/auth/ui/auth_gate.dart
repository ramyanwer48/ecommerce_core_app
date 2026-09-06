import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
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
    // ننتظر قليلاً لعرض شكل الشاشة الافتتاحية
    await Future.delayed(const Duration(seconds: 2));

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      bool authenticated = await _authenticateWithBiometrics();
      if (authenticated) {
        if (mounted) context.go(Routes.home);
      } else {
        FirebaseAuth.instance.signOut();
        if (mounted) context.go(Routes.login);
      }
    } else {
      if (mounted) context.go(Routes.login);
    }
  }

  Future<bool> _authenticateWithBiometrics() async {
    bool authenticated = false;
    try {
      setState(() { _isAuthenticating = true; });

      // نكتفي بتمرير الرسالة فقط لتجنب أي تعارض مع إصدارات المكتبة المختلفة
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
            const Text('RAMY STORE', style: TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 50),
            _isAuthenticating
                ? const Column(
              children: [
                Icon(Icons.fingerprint, size: 80, color: ColorsManager.lightBlue),
                SizedBox(height: 20),
                Text('بانتظار البصمة...', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            )
                : const CircularProgressIndicator(color: ColorsManager.neonBlue),
          ],
        ),
      ),
    );
  }
}