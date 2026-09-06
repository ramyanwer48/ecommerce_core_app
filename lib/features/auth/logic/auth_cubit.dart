import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/auth_repo.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepo _authRepo;

  AuthCubit(this._authRepo) : super(AuthInitial());

  // متحكمات النصوص (Controllers) لأخذ الكلام المكتوب في حقول الإدخال
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  // نموذج للتحقق من صحة الإدخالات (Form Key)
  final formKey = GlobalKey<FormState>();

  Future<void> emitLoginStates() async {
    // 1. إظهار حالة التحميل
    emit(AuthLoading());

    try {
      // 2. محاولة تسجيل الدخول عبر الـ Repo
      final response = await _authRepo.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // 3. في حالة النجاح
      if (response != null) {
        emit(AuthSuccess());
      }
    } catch (e) {
      // 4. في حالة الفشل (كلمة سر خاطئة مثلاً)
      emit(AuthFailure(e.toString()));
    }
  }
  Future<void> emitSignUpStates() async {
    emit(AuthLoading());
    try {
      final response = await _authRepo.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (response != null) {
        emit(AuthSuccess());
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }
  // لا تنسَ تفريغ الذاكرة عند إغلاق الشاشة
  @override
  Future<void> close() {
    emailController.dispose();
    passwordController.dispose();
    return super.close();
  }
}