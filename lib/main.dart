import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theming/colors.dart';
import 'firebase_options.dart';
import 'core/routing/app_router.dart';
import 'core/routing/routes.dart'; // 👈 استدعاء مسارات التطبيق
import 'core/di/dependency_injection.dart';
import 'features/home/logic/favorites/favorites_cubit.dart';
import 'dart:async'; // 👈 ضروري عشان الرادار (Timer) يشتغل
import 'dart:async'; // 👈 ضروري عشان الرادار (Timer) يشتغل
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("🔔 تم استقبال إشعار في الخلفية: ${message.messageId}");
}

// 🚀 دالة التوجيه الذكي (Deep Linking)
// 🚀 دالة التوجيه الذكي (Deep Linking) مع المعالجة
// 🚀 دالة التوجيه الذكي (Deep Linking) المعالجة بالكامل
void _handleNotificationClick(RemoteMessage message) {
  final data = message.data;

  if (data.containsKey('type') && data['type'] == 'order_update') {
    final orderId = data['orderId'];
    print("🎯 توجيه ذكي لتفاصيل الطلب رقم: $orderId");

    // 👈 العداد الذكي (الرادار): يراقب مسار التطبيق كل 300 جزء من الثانية
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      // قراءة اسم الشاشة اللي التطبيق واقف عليها حالياً
      final currentPath = AppRouter.router.routerDelegate.currentConfiguration.uri.toString();

      if (currentPath == Routes.home) {
        // بمجرد ما الـ AuthGate يخلص ويوصلنا للرئيسية وتستقر -> نفتح الطلبات
        timer.cancel(); // نوقف الرادار
        AppRouter.router.push(Routes.orders);
      }
      else if (currentPath == Routes.login || currentPath == Routes.orders) {
        // لو العميل مش مسجل دخول وراح للوجين، أو لو الشاشة فتحت بنجاح -> نلغي الرادار عشان مايفضلش شغال
        timer.cancel();
      }
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة الاتصال بالسحابة
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. تهيئة نظام الإشعارات الفورية (FCM)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.instance.getToken().then((fcmToken) {
    print("==============================================");
    print("📱 بصمة الجهاز (FCM Token): $fcmToken");
    print("==============================================");
  }).catchError((error) {
    print("❌ حدث خطأ أثناء جلب التوكن: $error");
  });

  // 🚀 3. تفعيل الـ Deep Linking لفتح الإشعارات

  // الحالة الأولى: التطبيق في الخلفية (العميل ضغط على الإشعار)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationClick(message);
  });

  // الحالة الثانية: التطبيق مغلق تماماً (Terminated) والعميل ضغط على الإشعار
  final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    // ننتظر نصف ثانية حتى يكتمل بناء الواجهة (Widgets) ثم نوجه العميل
    Future.delayed(const Duration(milliseconds: 500), () {
      _handleNotificationClick(initialMessage);
    });
  }

  // 4. تهيئة نظام حقن الاعتماديات قبل تشغيل واجهة التطبيق
  await setupGetIt();

  // تشغيل التطبيق فوراً
  runApp(const EcommerceApp());
}

class EcommerceApp extends StatelessWidget {
  const EcommerceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => getIt<FavoritesCubit>()..fetchFavorites(),
        ),
      ],
      child: MaterialApp.router(
        title: 'RAMY STORE',
        debugShowCheckedModeBanner: false,
        routerConfig: AppRouter.router,
        theme: ThemeData(
          scaffoldBackgroundColor: ColorsManager.mainDarkBlue,
          appBarTheme: const AppBarTheme(
            backgroundColor: ColorsManager.mainDarkBlue,
            elevation: 0,
            iconTheme: IconThemeData(color: ColorsManager.white),
          ),
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}