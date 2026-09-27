import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 📦 استدعاء شاشات العميل
import '../../features/home/ui/home_screen.dart';
import '../../features/cart/ui/cart_screen.dart';
import '../../features/profile/ui/profile_screen.dart';

// 📦 استدعاء شاشات الإدارة
import '../../features/admin/ui/admin_dashboard_screen.dart';
import '../../features/admin/ui/manage_products_screen.dart';
import '../../features/admin/ui/admin_orders_screen.dart';
import '../../features/purchases/ui/ai_purchase_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isAdmin = false;

  final Color appPrimaryColor = const Color(0xFF0B1E3F);
  final Color appSecondaryColor = const Color(0xFFFF9F0A);

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()?['role'] == 'admin') {
          _isAdmin = true;
        }
      } catch (e) {
        debugPrint('Error fetching role: $e');
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  // 👤 شاشات العميل العادي (4 شاشات)
  final List<Widget> _customerScreens = [
    const HomeScreen(),
    const Scaffold(body: Center(child: Text('شاشة الأقسام (قريباً)', style: TextStyle(fontFamily: 'Cairo')))),
    const CartScreen(),
    const ProfileScreen(),
  ];

  // 👨‍💼 شاشات الإدارة (5 شاشات - تم إضافة المتجر في البداية)
  final List<Widget> _adminScreens = [
    const HomeScreen(),             // 👈 شاشة العميل (المتجر) أصبحت الواجهة الأولى للأدمن
    const AdminDashboardScreen(),   // 👈 لوحة القيادة
    const ManageProductsScreen(),   // 👈 إدارة المخزون
    const AdminOrdersScreen(),      // 👈 الطلبات
    const AiPurchaseScreen(),       // 👈 المشتريات وإدخال الفواتير
  ];

  void _onItemTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: appSecondaryColor)),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _isAdmin ? _adminScreens : _customerScreens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            backgroundColor: Colors.white,
            selectedItemColor: appSecondaryColor,
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.normal, fontSize: 10),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: _isAdmin
                ? const [
              BottomNavigationBarItem(icon: Icon(Icons.storefront_rounded), label: 'المتجر'), // 👈 زر شاشة العميل
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'اللوحة'),
              BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'المخزون'),
              BottomNavigationBarItem(icon: Icon(Icons.local_shipping_rounded), label: 'الطلبات'),
              BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'المشتريات'),
            ]
                : const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
              BottomNavigationBarItem(icon: Icon(Icons.category_rounded), label: 'الأقسام'),
              BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_rounded), label: 'السلة'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'حسابي'),
            ],
          ),
        ),
      ),
    );
  }
}