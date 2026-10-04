import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/admin/ui/purchases_history_screen.dart';
import '../di/dependency_injection.dart';
import 'routes.dart';

// --- استدعاءات الأساسيات (Core) والسبلاش ---
import '../../features/splash/ui/splash_screen.dart';
import '../../shared/ui/main_layout_screen.dart';

// --- استدعاءات Auth ---
import '../../features/auth/logic/auth_cubit.dart';
import '../../features/auth/ui/auth_gate.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/signup_screen.dart';

// --- استدعاءات Home & Cart ---
import '../../features/home/logic/home_cubit.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/home/ui/product_details_screen.dart';
import '../../features/home/data/models/product_model.dart';
import '../../features/cart/ui/cart_screen.dart';
import '../../features/cart/logic/cart_cubit.dart';
import '../../features/home/logic/favorites/favorites_cubit.dart';

// --- استدعاءات Checkout & Addresses ---
import '../../features/checkout/data/repos/checkout_repo.dart';
import '../../features/checkout/logic/checkout_cubit.dart';
import '../../features/checkout/ui/addresses_screen.dart';
import '../../features/checkout/ui/checkout_screen.dart';

// --- استدعاءات Profile ---
import '../../features/profile/data/repos/order_repo.dart';
import '../../features/profile/logic/order_cubit.dart';
import '../../features/profile/ui/orders_screen.dart';
import '../../features/profile/ui/profile_screen.dart';

// --- استدعاءات قسم الإدارة (Admin & ERP Hub) ---
import '../../features/admin/ui/admin_dashboard_screen.dart';
import '../../features/admin/data/repos/admin_repo.dart';
import '../../features/admin/ui/add_product_screen.dart';
import '../../features/admin/logic/add_product_cubit.dart';
import '../../features/admin/ui/manage_products_screen.dart';
import '../../features/admin/data/repos/admin_categories_repo.dart';
import '../../features/admin/logic/admin_categories_cubit.dart';
import '../../features/admin/ui/manage_categories_screen.dart';
import '../../features/admin/data/repos/admin_orders_repo.dart';
import '../../features/admin/logic/admin_orders_cubit.dart';
import '../../features/admin/ui/admin_orders_screen.dart';
import '../../features/admin/data/repos/admin_coupons_repo.dart';
import '../../features/admin/logic/admin_coupons_cubit.dart';
import '../../features/admin/ui/admin_coupons_screen.dart';
import '../../features/admin/ui/admin_banner_screen.dart';

// --- استدعاءات المشتريات (Purchases) ---
import '../../features/purchases/ui/ai_purchase_screen.dart';
import '../../features/purchases/ui/invoice_review_screen.dart';
import '../../features/admin/ui/manual_purchase_screen.dart';

// --- استدعاءات الفواتير (Invoices) ---
import '../../features/invoices/data/repos/invoice_repo.dart';
import '../../features/invoices/logic/invoice_cubit.dart';
import '../../features/admin/ui/sales_invoices_screen.dart';
import '../../features/admin/ui/purchase_invoices_screen.dart';

// --- استدعاءات متنوعة ---
import '../../features/wishlist/ui/wishlist_screen.dart';
import '../../features/partners/ui/partners_screen.dart';
import '../../features/partners/ui/customers_screen.dart';
import '../../features/admin/ui/pos_screen.dart';
import '../../features/admin/ui/inventory_audit_screen.dart';
import '../../features/admin/ui/treasury_screen.dart';
import '../../features/admin/ui/shipping_companies_screen.dart';


class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth-gate',
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
      GoRoute(
        path: Routes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: Routes.addProduct,
        builder: (context, state) {
          final productData = state.extra as Map<String, dynamic>?;
          return BlocProvider(
            create: (context) => AddProductCubit(AdminRepo()),
            child: AddProductScreen(productData: productData),
          );
        },
      ),
      GoRoute(
        path: Routes.adminOrders,
        builder: (context, state) => BlocProvider(
          create: (context) => getIt<AdminOrdersCubit>()..fetchAllOrders(),
          child: const AdminOrdersScreen(),
        ),
      ),
      GoRoute(
        path: Routes.manageCoupons,
        builder: (context, state) => BlocProvider(
          create: (context) => AdminCouponsCubit(AdminCouponsRepo()),
          child: const AdminCouponsScreen(),
        ),
      ),
      GoRoute(
        path: Routes.manageProducts,
        builder: (context, state) => const ManageProductsScreen(),
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
      GoRoute(
        path: Routes.adminBanner,
        builder: (context, state) => const AdminBannerScreen(),
      ),
      GoRoute(
        path: Routes.aiPurchase,
        builder: (context, state) => const AiPurchaseScreen(),
      ),
      GoRoute(
        path: Routes.invoiceReview,
        builder: (context, state) {
          final invoiceData = state.extra as Map<String, dynamic>?;
          return InvoiceReviewScreen(invoiceData: invoiceData);
        },
      ),
      GoRoute(
        path: Routes.mainLayout,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (context) => getIt<HomeCubit>()..fetchProducts()),
            BlocProvider(create: (context) => getIt<FavoritesCubit>()),
            BlocProvider(create: (context) => getIt<CartCubit>()),
          ],
          child: const MainLayoutScreen(),
        ),
      ),

      // --- مسارات المشتريات الجديدة ---
      GoRoute(
        path: Routes.manualPurchase,
        builder: (context, state) => const ManualPurchaseScreen(),
      ),

      // --- مسارات الفواتير الجديدة (Invoices) ---
      GoRoute(
        path: Routes.salesInvoices,
        builder: (context, state) => BlocProvider(
          create: (context) => InvoiceCubit(InvoiceRepo()),
          child: const SalesInvoicesScreen(),
        ),
      ),
      GoRoute(
        path: Routes.purchaseInvoices,
        builder: (context, state) => BlocProvider(
          create: (context) => InvoiceCubit(InvoiceRepo()),
          child: const PurchaseInvoicesScreen(),
        ),
      ),
      GoRoute(
        path: Routes.purchasesHistory,
        builder: (context, state) => const PurchasesHistoryScreen(),
      ),
      GoRoute(
        path: Routes.customers,
        builder: (context, state) => const CustomersScreen(),
      ),
      GoRoute(
        path: Routes.pos,
        builder: (context, state) => const PosScreen(),
      ),
      GoRoute(
        path: Routes.inventoryAudit,
        builder: (context, state) => const InventoryAuditScreen(),
      ),
      GoRoute(
        path: Routes.treasury,
        builder: (context, state) => const TreasuryScreen(),
      ),
      GoRoute(
        path: Routes.shippingCompanies,
        builder: (context, state) => const ShippingCompaniesScreen(),
      ),
    ],
  );
}