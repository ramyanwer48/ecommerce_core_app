import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // تم إضافة مكتبة الحماية هنا
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// تم إزالة استيراد PaymobManager لأنه لم يعد مطلوباً في التهيئة الأولية للتطبيق
import 'core/theming/colors.dart';
import 'firebase_options.dart';
import 'core/routing/app_router.dart';
import 'core/routing/routes.dart';
import 'core/di/dependency_injection.dart';
import 'features/home/logic/favorites/favorites_cubit.dart';
import 'features/cart/logic/cart_cubit.dart';
import 'dart:async';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> _saveFCMTokenToFirestore(String token) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  } catch (_) {}
}

void _handleNotificationClick(RemoteMessage message) {
  final data = message.data;

  if (data.containsKey('type') && data['type'] == 'order_update') {
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      final currentPath = AppRouter.router.routerDelegate.currentConfiguration.uri.toString();

      if (currentPath == Routes.home) {
        timer.cancel();
        AppRouter.router.push(Routes.orders);
      } else if (currentPath == Routes.login || currentPath == Routes.orders) {
        timer.cancel();
      }
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ---------- تفعيل حماية Firebase App Check ----------
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
  // ----------------------------------------------------

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.instance.getToken().then((fcmToken) {
    if (fcmToken != null) {
      _saveFCMTokenToFirestore(fcmToken);
    }
  }).catchError((_) {});

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    _saveFCMTokenToFirestore(newToken);
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {});

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationClick(message);
  });

  final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    Future.delayed(const Duration(milliseconds: 500), () {
      _handleNotificationClick(initialMessage);
    });
  }

  await setupGetIt();

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
        BlocProvider(
          create: (context) => getIt<CartCubit>(),
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