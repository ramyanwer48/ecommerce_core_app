import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// استدعاءات Auth
import '../../features/auth/logic/auth_cubit.dart';
import '../../features/auth/ui/auth_gate.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/signup_screen.dart';

// استدعاءات Home
import '../../features/home/logic/home_cubit.dart';
import '../../features/home/ui/home_screen.dart';

// استدعاءات الأساسيات (Core)
import '../di/dependency_injection.dart'; // تم توحيد الاستدعاء هنا بدون أي مسافات زائدة
import 'routes.dart';

import '../../features/home/ui/product_details_screen.dart';
import '../../features/home/data/models/product_model.dart'; // ستحتاجه لتمرير البيانات

import '../../features/cart/ui/cart_screen.dart';
import '../../features/cart/logic/cart_cubit.dart';
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
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
        builder: (context, state) => BlocProvider(
          create: (context) => getIt<HomeCubit>()..fetchProducts(),
          child: const HomeScreen(),
        ),
      ),
  GoRoute(
  path: Routes.productDetails,
  builder: (context, state) {
  final product = state.extra as ProductModel;
  return ProductDetailsScreen(product: product);
  },
  ), // <--- هذا القوس كان مفقوداً عندك لإغلاق مسار التفاصيل

  GoRoute(
  path: Routes.cart,
  builder: (context, state) => BlocProvider.value(
  value: getIt<CartCubit>(),
  child: const CartScreen(),
  ),
  ),
    ],
  );
}