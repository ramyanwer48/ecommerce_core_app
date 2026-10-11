import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/di/dependency_injection.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/cart/ui/cart_screen.dart';
import '../../features/profile/ui/profile_screen.dart';
import '../../features/profile/ui/orders_screen.dart';
import '../../features/admin/ui/admin_dashboard_screen.dart';
import '../../features/admin/ui/manage_products_screen.dart';
import '../../features/admin/ui/admin_orders_screen.dart';
import '../../features/admin/logic/admin_orders_cubit.dart';
import '../../features/cart/logic/cart_cubit.dart';
import '../../features/cart/logic/cart_state.dart';
import '../../features/purchases/ui/ai_purchase_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;
  bool _isAdmin = false;

  final Color appSecondaryColor = const Color(0xFFFF9F0A);

  // 🌟 [السر هنا] مفاتيح ملاحة مستقلة لكل تاب عشان الشريط يفضل ثابت
  final List<GlobalKey<NavigatorState>> _adminNavKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
  final List<GlobalKey<NavigatorState>> _customerNavKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

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
          if (mounted) {
            setState(() => _isAdmin = true);
          }
        }
      } catch (e) {
        debugPrint('Error fetching role: $e');
      }
    }
  }

  final List<Widget> _customerScreens = [
    const HomeScreen(),
    const OrdersScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  final List<Widget> _adminScreens = [
    const HomeScreen(),
    const AiPurchaseScreen(),
    const AdminDashboardScreen(),
    const ManageProductsScreen(),
    BlocProvider(
      create: (context) => getIt<AdminOrdersCubit>(),
      child: const AdminOrdersScreen(),
    ),
  ];

  void _onItemTapped(int index) {
    HapticFeedback.selectionClick();
    if (_currentIndex == index) {
      // 🌟 [ميزة احترافية] لو داس على التاب وهو جواه أصلاً، يرجعه لأول شاشة في التاب ده
      final currentNavKey = _isAdmin ? _adminNavKeys[index] : _customerNavKeys[index];
      currentNavKey.currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _currentIndex = index);
    }
  }

  // 🌟 دالة بناء (شاشة مصغرة) لكل تاب عشان نحافظ على شريطه السفلي
  Widget _buildOffstageNavigator(int index, Widget screen, GlobalKey<NavigatorState> key) {
    return Offstage(
      offstage: _currentIndex != index,
      child: Navigator(
        key: key,
        onGenerateRoute: (routeSettings) {
          return MaterialPageRoute(builder: (context) => screen);
        },
      ),
    );
  }

  Widget _buildCartIconWithBadge(bool isActive) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        int badgeCount = 0;
        if (state is CartUpdated) badgeCount = state.totalQuantity;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.shopping_cart_rounded, color: isActive ? appSecondaryColor : Colors.grey.shade400),
            if (badgeCount > 0)
              Positioned(
                right: -6, top: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    badgeCount.toString().replaceAllMapped(RegExp(r'[0-9]'), (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) + 1584)),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentNavKeys = _isAdmin ? _adminNavKeys : _customerNavKeys;
    final currentScreens = _isAdmin ? _adminScreens : _customerScreens;

    // 🌟 PopScope: للتحكم في زرار الرجوع بتاع الأندرويد
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final currentNavigator = currentNavKeys[_currentIndex].currentState;

        // لو فاتح كارت فرعي (زي الجرد)، ارجع خطوة جواه الأول
        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
        } else {
          // لو في الشاشة الرئيسية للتاب، ارجع لتاب (المتجر)
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
          } else {
            // لو في تاب المتجر ومفيش شاشات مفتوحة، اقفل التطبيق
            SystemNavigator.pop();
          }
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          // 🌟 استخدام Stack لتركيب الشاشات فوق بعضها والاحتفاظ بمسار كل واحدة
          body: Stack(
            children: List.generate(currentScreens.length, (index) {
              return _buildOffstageNavigator(index, currentScreens[index], currentNavKeys[index]);
            }),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            backgroundColor: Colors.white,
            selectedItemColor: appSecondaryColor,
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.normal, fontSize: 10),
            type: BottomNavigationBarType.fixed,
            items: _isAdmin
                ? [
              const BottomNavigationBarItem(icon: Icon(Icons.storefront_rounded), label: 'المتجر'),
              const BottomNavigationBarItem(icon: Icon(Icons.document_scanner_rounded), label: 'فاتورة AI ✨'),
              const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'اللوحة'),
              const BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'المخزون'),
              const BottomNavigationBarItem(icon: Icon(Icons.local_shipping_rounded), label: 'الطلبات'),
            ]
                : [
              const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
              const BottomNavigationBarItem(icon: Icon(Icons.local_shipping_rounded), label: 'طلباتي'),
              BottomNavigationBarItem(icon: _buildCartIconWithBadge(_currentIndex == 2), label: 'السلة'),
              const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'حسابي'),
            ],
          ),
        ),
      ),
    );
  }
}