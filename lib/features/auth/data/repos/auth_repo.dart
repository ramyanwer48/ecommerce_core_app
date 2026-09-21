import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthRepo {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthRepo(this._firebaseAuth);

  // دالة تسجيل الدخول (مع تحديث توكن الإشعارات)
  Future<UserCredential?> login({required String email, required String password, String? fcmToken}) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // تحديث توكن الإشعارات فقط لو العميل سجل دخول من جهاز جديد
      if (userCredential.user != null && fcmToken != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set(
          {'fcmToken': fcmToken},
          SetOptions(merge: true),
        );
      }

      return userCredential;
    } catch (e) {
      print('Login Error: $e');
      throw Exception(e.toString());
    }
  }

  // دالة إنشاء حساب جديد (مدمج فيها شغل الفايرستور والتوكن)
  Future<UserCredential?> signUp({required String name, required String email, required String password, String? fcmToken}) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final userModel = UserModel(
          uid: userCredential.user!.uid,
          name: name.isNotEmpty ? name : 'عميل جديد',
          email: email,
          // role: 'customer' // الصلاحية الافتراضية بتتضاف أوتوماتيك من الموديل
        );

        // إنشاء مستند المستخدم وحفظ التوكن
        Map<String, dynamic> userData = userModel.toMap();
        if (fcmToken != null) userData['fcmToken'] = fcmToken;

        await _firestore.collection('users').doc(userCredential.user!.uid).set(userData);
      }

      return userCredential;
    } catch (e) {
      print('SignUp Error: $e');
      throw Exception(e.toString());
    }
  }

  // دالة لجلب بيانات المستخدم لمعرفة صلاحيته (Role)
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Get User Data Error: $e');
      return null;
    }
  }
}