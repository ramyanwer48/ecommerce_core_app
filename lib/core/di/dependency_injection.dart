import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/home/data/repos/home_repo.dart';
import '../../features/auth/data/repos/auth_repo.dart'; // استدعاء مستودع الأمان
import '../../features/auth/logic/auth_cubit.dart'; // لا تنس الاستدعاء
final GetIt getIt = GetIt.instance;

Future<void> setupGetIt() async {
  // خدمات Firebase المركزية
  getIt.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);

  // مستودعات التطبيق (Repositories)
  getIt.registerLazySingleton<HomeRepo>(() => HomeRepo(getIt()));
  getIt.registerLazySingleton<AuthRepo>(() => AuthRepo(getIt())); // تسجيل AuthRepo

  // ... في نهاية دالة setupGetIt أضف:
// استخدمنا Factory هنا لأننا نريد نسخة جديدة من الـ Cubit في كل مرة تُفتح فيها الشاشة
  getIt.registerFactory<AuthCubit>(() => AuthCubit(getIt()));
}