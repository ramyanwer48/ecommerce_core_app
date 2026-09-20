import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/routes.dart'; // تأكد إن مسار الروتس صح عندك

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // الشاشة البيضاء المؤقتة أثناء الفحص
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Colors.white);
        }

        // 👈 التوجيه الصحيح عبر GoRouter لحل مشكلة التعليق
        Future.microtask(() {
          if (snapshot.hasData) {
            context.go(Routes.home); // لو مسجل دخول، روح للرئيسية
          } else {
            context.go(Routes.login); // لو مش مسجل، روح لتسجيل الدخول
          }
        });

        // شاشة بيضاء لأجزاء من الثانية لحين تنفيذ الانتقال
        return const Scaffold(backgroundColor: Colors.white);
      },
    );
  }
}