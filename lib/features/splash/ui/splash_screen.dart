import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        context.go('/auth-gate');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. قراءة الصورة بأبعادها وفردها على أي شاشة موبايل
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.asset(
              'assets/images/splash_screen.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2. خط التحميل البرتقالي الصافي
          Align(
            alignment: const Alignment(0, 0.38), // مرفوع للأعلى ليبعد عن النصوص
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 100),
              child: Container(
                height: 4,
                // 👈 تم إزالة الـ BoxDecoration والـ BoxShadow اللي كان عامل الوهج البرتقالي تماماً
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    backgroundColor: Colors.transparent, // 👈 خلفية شفافة
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}