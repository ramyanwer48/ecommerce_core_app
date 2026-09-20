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
          // 1. قراءة الصورة بأبعادها وفردها على أي شاشة موبايل (Honor, Samsung, iPhone)
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.asset(
              'assets/images/splash_screen.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2. خط التحميل النيون البرتقالي (تم ضبط مكانه في الثلث السفلي لتجنب تغطية النصوص)
          Align(
            alignment: const Alignment(0, 0.85), // نزلته شوية عشان يبقى تحت Version 1
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 100), // تصغير عرض الخط ليكون أنيقاً
              child: Container(
                height: 4, // سمك الخط
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.shade600.withOpacity(0.6),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
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