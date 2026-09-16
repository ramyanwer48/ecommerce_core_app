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

// استدعاءات Home & Checkout & Addresses
import '../../features/checkout/data/repos/checkout_repo.dart';
import '../../features/checkout/logic/checkout_cubit.dart';
import '../../features/checkout/ui/addresses_screen.dart';
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
import '../../features/profile/ui/profile_screen.dart';

// استدعاءات الأساسيات (Core)
import '../di/dependency_injection.dart';
import 'routes.dart';

// استدعاءات قسم الإدارة (Admin & ERP Hub)
import '../../features/admin/ui/add_product_screen.dart';
import '../../features/admin/logic/add_product_cubit.dart';
import '../../features/admin/data/repos/admin_repo.dart';
import '../../features/admin/ui/admin_orders_screen.dart';
import '../../features/admin/logic/admin_orders_cubit.dart';
import '../../features/admin/data/repos/admin_orders_repo.dart';
import '../../features/admin/ui/admin_dashboard_screen.dart'; // 👈 استدعاء لوحة التحكم المركزية

import '../../features/wishlist/ui/wishlist_screen.dart';

// استدعاء شاشة إدارة الأطراف (العملاء والموردين)
import '../../features/partners/ui/partners_screen.dart';

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
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: Routes.orders,
        builder: (context, state) => BlocProvider(
          create: (context) => OrderCubit(OrderRepo())..fetchOrders(),
          child: const OrdersScreen(),
        ),
      ),

      // 👈 مسار لوحة تحكم الأدمن المركزية الجديد
      GoRoute(
        path: Routes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
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
            create: (context) => AdminCategoriesCubit(AdminCategoriesRepo()),
            child: const ManageCategoriesScreen(),
          );
        },
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          final cartTotal = state.extra as double? ?? 0.0;
          return BlocProvider(
            create: (context) => CheckoutCubit(CheckoutRepo()),
            child: CheckoutScreen(cartTotal: cartTotal),
          );
        },
      ),
      GoRoute(
        path: '/addresses',
        builder: (context, state) => const AddressesScreen(),
      ),
      GoRoute(
        path: Routes.partners,
        builder: (context, state) => const PartnersScreen(),
      ),
    ],
  );
}