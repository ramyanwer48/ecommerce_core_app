import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/logic/auth_cubit.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/signup_screen.dart';
import '../di/dependency_injection.dart';
import 'routes.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/auth/ui/auth_gate.dart';

// --- المتحكم المركزي في مسارات التطبيق ---
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: Routes.splash, // التطبيق يبدأ من مسار الـ splash
    routes: [
      GoRoute(
        path: Routes.splash,
        // تم استبدال الشاشة القديمة بالبوابة الذكية التي تفحص الدخول وتطلب البصمة
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => BlocProvider(
          create: (context) => getIt<AuthCubit>(),
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: Routes.signUp,
        builder: (context, state) => BlocProvider(
          create: (context) => getIt<AuthCubit>(),
          child: const SignUpScreen(),
        ),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
}