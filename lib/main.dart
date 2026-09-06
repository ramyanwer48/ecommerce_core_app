import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theming/colors.dart';
import 'firebase_options.dart';
import 'core/routing/app_router.dart'; // استدعاء ملف التوجيه
import 'core/di/dependency_injection.dart'; // استدعاء ملف GetIt
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة الاتصال بالسحابة
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. تهيئة نظام حقن الاعتماديات قبل تشغيل واجهة التطبيق
  await setupGetIt();

  runApp(const EcommerceApp());
}

class EcommerceApp extends StatelessWidget {
  const EcommerceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RAMY STORE',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      // --- تمت إضافة الكود من هنا ---
      theme: ThemeData(
        scaffoldBackgroundColor: ColorsManager.mainDarkBlue, // جعل خلفية كل الشاشات كحلية
        appBarTheme: const AppBarTheme(
          backgroundColor: ColorsManager.mainDarkBlue,
          elevation: 0, // إزالة الظل تحت الـ AppBar
          iconTheme: IconThemeData(color: ColorsManager.white),
        ),
        fontFamily: 'Cairo', // سنضيف هذا الخط لاحقاً ليصبح التطبيق بخط عربي احترافي
      ),
      // --- إلى هنا ---
    );
  }
}