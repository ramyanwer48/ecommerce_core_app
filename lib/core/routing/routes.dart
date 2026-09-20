class Routes {
  static const String splash = '/'; // 👈 السبلاش هتاخد المسار الرئيسي '/'
  static const String login = '/login';
  static const String signUp = '/signUp';
  static const String home = '/home';
  static const String productDetails = '/productDetails';
  static const String cart = '/cart';
  static const String profile = '/profile';
  static const String orders = '/orders';

  // مسارات الإدارة المركزية (Admin Dashboard & ERP Hub)
  static const String adminDashboard = '/adminDashboard'; // 👈 لوحة التحكم المركزية
  static const String addProduct = '/addProduct';
  static const String adminOrders = '/adminOrders';
  static const String manageProducts = '/manageProducts';
  static const String manageCategories = '/manageCategories';

  static const String wishlist = '/wishlist';
  static const String checkout = '/checkout';
  static const String addresses = '/addresses';

  // مسار شاشة الأطراف (العملاء والموردين)
  static const String partners = '/partners';
  static const String createInvoice = '/createInvoice';
  static const String manageCoupons = '/manageCoupons';
}