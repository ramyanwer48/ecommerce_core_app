import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../data/repos/auth_repo.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepo _authRepo;

  AuthCubit(this._authRepo) : super(AuthInitial());

  // متحكمات النصوص (Controllers)
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  // نموذج للتحقق من صحة الإدخالات (Form Key)
  final formKey = GlobalKey<FormState>();

  Future<void> emitLoginStates() async {
    emit(AuthLoading());
    try {
      // جلب توكن الإشعارات
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      final response = await _authRepo.login(
        email: emailController.text.trim(),
        password: passwordController.text,
        fcmToken: fcmToken,
      );

      if (response != null) {
        emit(AuthSuccess());
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> emitSignUpStates() async {
    emit(AuthLoading());
    try {
      // جلب توكن الإشعارات
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      final response = await _authRepo.signUp(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        fcmToken: fcmToken,
      );

      if (response != null) {
        emit(AuthSuccess());
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  @override
  Future<void> close() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    return super.close();
  }
}