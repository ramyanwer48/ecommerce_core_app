import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 👈 استدعاء مكتبة الإشعارات
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
      final response = await _authRepo.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (response != null) {
        // 👈 الكود الجديد: تحديث التوكن في الفايربيز عند تسجيل الدخول
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          String? fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
              {'fcmToken': fcmToken},
              SetOptions(merge: true), // 👈 مهم جداً: لتحديث حقل التوكن فقط دون مسح باقي البيانات
            );
          }
        }
        emit(AuthSuccess());
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> emitSignUpStates() async {
    emit(AuthLoading());
    try {
      // 1. إنشاء الحساب في الـ Authentication
      final response = await _authRepo.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (response != null) {
        // 2. الكود السحري: إنشاء مستند المستخدم في الـ Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // 👈 الكود الجديد: جلب التوكن لربطه بالحساب الجديد
          String? fcmToken = await FirebaseMessaging.instance.getToken();

          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': nameController.text.trim().isNotEmpty ? nameController.text.trim() : 'عميل جديد',
            'email': emailController.text.trim(),
            'role': 'user',
            'fcmToken': fcmToken, // 👈 حفظ التوكن في قاعدة البيانات
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // 3. إعلان النجاح بعد إتمام الخطوتين
        emit(AuthSuccess());
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  // لا تنسَ تفريغ الذاكرة عند إغلاق الشاشة
  @override
  Future<void> close() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    return super.close();
  }
}