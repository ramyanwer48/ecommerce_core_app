import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/data/repos/auth_repo.dart';
import '../../features/auth/logic/auth_cubit.dart';
import '../../features/home/data/repos/home_repo.dart';
import '../../features/home/logic/home_cubit.dart';
import '../../features/cart/logic/cart_cubit.dart';
import '../../features/home/logic/reviews/reviews_cubit.dart';
import '../../features/home/logic/favorites/favorites_cubit.dart';

// استيراد ملفات الأدمن وإدارة الطلبات
import '../../features/admin/data/repos/admin_repo.dart';
import '../../features/admin/data/repos/admin_orders_repo.dart';
import '../../features/admin/logic/admin_orders_cubit.dart';

// 👈 استيراد ملفات الفواتير
import '../../features/invoices/data/repos/invoice_repo.dart';
import '../../features/invoices/logic/invoice_cubit.dart'; // 👈 تمت إضافة استيراد الكيوبيت هنا

final GetIt getIt = GetIt.instance;

Future<void> setupGetIt() async {
  // خدمات Firebase المركزية
  getIt.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);

  // --- قسم المصادقة (Auth) ---
  getIt.registerLazySingleton<AuthRepo>(() => AuthRepo(getIt()));
  getIt.registerFactory<AuthCubit>(() => AuthCubit(getIt()));

  // --- قسم الرئيسية (Home) ---
  getIt.registerLazySingleton<HomeRepo>(() => HomeRepo());
  getIt.registerFactory<HomeCubit>(() => HomeCubit(getIt()));

  // Cart
  getIt.registerLazySingleton<CartCubit>(() => CartCubit());

  getIt.registerFactory<ReviewsCubit>(() => ReviewsCubit());
  getIt.registerLazySingleton<FavoritesCubit>(() => FavoritesCubit());

  // --- 🌟 قسم الأدمن وإدارة الطلبات ---
  getIt.registerLazySingleton<AdminRepo>(() => AdminRepo());
  getIt.registerLazySingleton<AdminOrdersRepo>(() => AdminOrdersRepo());

  // --- 🧾 قسم الفواتير ---
  getIt.registerLazySingleton<InvoiceRepo>(() => InvoiceRepo());
  // 👈 الإضافة الجديدة هنا: تسجيل InvoiceCubit ليتمكن التطبيق من إيجاده
  getIt.registerFactory<InvoiceCubit>(() => InvoiceCubit(getIt<InvoiceRepo>()));

  // حقن AdminOrdersCubit
  getIt.registerFactory<AdminOrdersCubit>(
        () => AdminOrdersCubit(
      getIt<AdminOrdersRepo>(),
      getIt<AdminRepo>(),
      getIt<InvoiceRepo>(),
    ),
  );
}