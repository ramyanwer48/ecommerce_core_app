import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// استدعاءات Auth
import '../../features/admin/data/repos/admin_categories_repo.dart';
import '../../features/admin/logic/admin_categories_cubit.dart';
import '../../features/admin/ui/manage_categories_screen.dart';
import '../../features/admin/ui/manage_products_screen.dart';
import '../../features/auth/logic/auth_cubit.dart';
import '../../features/auth/ui/auth_gate.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/signup_screen.dart';

// استدعاءات Home
import '../../features/checkout/data/repos/checkout_repo.dart';
import '../../features/checkout/logic/checkout_cubit.dart';
import '../../features/checkout/ui/checkout_screen.dart';
import '../../features/home/logic/home_cubit.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/home/ui/product_details_screen.dart';
import '../../features/home/data/models/product_model.dart';

// استدعاءات Cart
import '../../features/cart/ui/cart_screen.dart';
import '../../features/cart/logic/cart_cubit.dart';

// استدعاءات Profile
import '../../features/profile/data/repos/order_repo.dart';
import '../../features/profile/logic/order_cubit.dart';
import '../../features/profile/ui/orders_screen.dart';
import '../../features/profile/ui/profile_screen.dart'; // <--- استدعاء شاشة الملف الشخصي

// استدعاءات الأساسيات (Core)
import '../di/dependency_injection.dart';
import 'routes.dart';

// في الأعلى ضع الاستدعاءات:
// import '../../features/profile/ui/orders_screen.dart';
// import '../../features/profile/logic/order_cubit.dart';
// import '../../features/profile/data/repos/order_repo.dart';

// استدعاءات قسم الإدارة (Admin)
import '../../features/admin/ui/add_product_screen.dart';
import '../../features/admin/logic/add_product_cubit.dart';
import '../../features/admin/data/repos/admin_repo.dart';

import '../../features/admin/ui/admin_orders_screen.dart';
import '../../features/admin/logic/admin_orders_cubit.dart';
import '../../features/admin/data/repos/admin_orders_repo.dart';

import '../../features/wishlist/ui/wishlist_screen.dart';

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
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (context) => getIt<HomeCubit>()..fetchProducts()),
          ],
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: Routes.productDetails,
        builder: (context, state) {
          final product = state.extra as ProductModel;
          return ProductDetailsScreen(product: product);
        },
      ),
      GoRoute(
        path: Routes.cart,
        builder: (context, state) => BlocProvider.value(
          value: getIt<CartCubit>(),
          child: const CartScreen(),
        ),
      ),
      // مسار شاشة الملف الشخصي الجديد
      GoRoute(
        path: Routes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: Routes.orders,
        builder: (context, state) => BlocProvider(
          create: (context) => OrderCubit(OrderRepo())..fetchOrders(), // سيقوم بجلب الطلبات فور فتح الشاشة
          child: const OrdersScreen(),
        ),
      ),
      GoRoute(
        path: Routes.addProduct,
        builder: (context, state) => BlocProvider(
          create: (context) => AddProductCubit(AdminRepo()),
          child: const AddProductScreen(),
        ),
      ),
      GoRoute(
        path: Routes.adminOrders,
        builder: (context, state) => BlocProvider(
          // استدعاء fetchAllOrders() هنا مهم جداً لجلب الطلبات تلقائياً بمجرد فتح الشاشة
          create: (context) => AdminOrdersCubit(AdminOrdersRepo())..fetchAllOrders(),
          child: const AdminOrdersScreen(),
        ),
      ),
      GoRoute(
        path: Routes.manageProducts,
        builder: (context, state) => ManageProductsScreen(),
      ),
      GoRoute(
      path: Routes.wishlist,
  builder: (context, state) => const WishlistScreen(),
  ),
      GoRoute(
        path: Routes.manageCategories,
        builder: (context, state) {
          return BlocProvider(
            // 👈 هنا بنقول للتطبيق: الشاشة دي بتشتغل بالكيوبيت ده والريبو ده
            create: (context) => AdminCategoriesCubit(AdminCategoriesRepo()),
            child: const ManageCategoriesScreen(),
          );
        },
      ),

      // 👇 هنا المكان الصحيح لمسار الـ Checkout (بره المسار اللي فوقيه) 👇
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          // هنا بنستقبل الإجمالي اللي جيالنا من السلة، ولو مفيش بنخليه 0.0
          final cartTotal = state.extra as double? ?? 0.0;

          return BlocProvider(
            create: (context) => CheckoutCubit(CheckoutRepo()),
            child: CheckoutScreen(cartTotal: cartTotal),
          );
        },
      ),
    ], // 👈 قفلة مصفوفة الـ routes
  );
}