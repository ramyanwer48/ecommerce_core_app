import 'package:firebase_auth/firebase_auth.dart';

class AuthRepo {
  final FirebaseAuth _firebaseAuth;

  AuthRepo(this._firebaseAuth);

  // دالة تسجيل الدخول
  Future<UserCredential?> login({required String email, required String password}) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } catch (e) {
      print('Login Error: $e');
      // سنقوم لاحقاً بإرسال رسالة خطأ واضحة للمستخدم
      throw Exception(e.toString());
    }
  }

  // دالة إنشاء حساب جديد (سنحتاجها لاحقاً)
  Future<UserCredential?> signUp({required String email, required String password}) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } catch (e) {
      print('SignUp Error: $e');
      throw Exception(e.toString());
    }
  }
}