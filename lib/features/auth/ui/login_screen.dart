import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theming/colors.dart';
import '../../../core/theming/styles.dart';
import '../logic/auth_cubit.dart';
import '../logic/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRememberMeChecked = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  // 1. استدعاء الإيميل المحفوظ عند فتح الشاشة
  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');

    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _isRememberMeChecked = true;
      });
      // نستخدم microtask لضمان بناء الـ context أولاً قبل تمرير البيانات للـ Cubit
      Future.microtask(() {
        if (mounted) {
          context.read<AuthCubit>().emailController.text = savedEmail;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) async {
            if (state is AuthSuccess) {
              // 2. التحقق من الرسالة الذكية للبصمة بعد نجاح الدخول
              final prefs = await SharedPreferences.getInstance();
              bool hasAskedBiometric = prefs.getBool('has_asked_biometric') ?? false;

              if (!hasAskedBiometric && mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: ColorsManager.mainDarkBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('تفعيل البصمة', style: TextStyle(color: ColorsManager.white, fontWeight: FontWeight.bold)),
                    content: const Text(
                      'هل ترغب في استخدام البصمة لتسجيل الدخول السريع والأمن في المرات القادمة؟',
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          prefs.setBool('isBiometricEnabled', false);
                          prefs.setBool('has_asked_biometric', true);
                          Navigator.pop(dialogContext); // إغلاق الرسالة
                          context.go(Routes.home); // التوجيه للمتجر
                        },
                        child: const Text('لا، شكراً', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorsManager.neonBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          prefs.setBool('isBiometricEnabled', true);
                          prefs.setBool('has_asked_biometric', true);
                          Navigator.pop(dialogContext); // إغلاق الرسالة
                          context.go(Routes.home); // التوجيه للمتجر
                        },
                        child: const Text('تفعيل', style: TextStyle(color: ColorsManager.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              } else {
                // إذا سُئل من قبل، يذهب للمتجر مباشرة
                if (mounted) context.go(Routes.home);
              }
            } else if (state is AuthFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage),
                  backgroundColor: ColorsManager.errorRed,
                ),
              );
            }
          },
          builder: (context, state) {
            final cubit = context.read<AuthCubit>();
            return Form(
              key: cubit.formKey,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'RAMY STORE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: ColorsManager.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'مرحباً بك مجدداً',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: ColorsManager.lightBlue,
                        ),
                      ),
                      const SizedBox(height: 50),

                      TextFormField(
                        controller: cubit.emailController,
                        style: const TextStyle(color: ColorsManager.white),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال البريد الإلكتروني';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'البريد الإلكتروني',
                          hintStyle: TextStyles.font14LightGrayRegular,
                          prefixIcon: const Icon(Icons.email_outlined, color: ColorsManager.lightBlue),
                          filled: true,
                          fillColor: ColorsManager.mainDarkBlue,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ColorsManager.darkGray, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ColorsManager.lightBlue, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ColorsManager.errorRed, width: 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: cubit.passwordController,
                        obscureText: true,
                        style: const TextStyle(color: ColorsManager.white),
                        validator: (value) {
                          if (value == null || value.isEmpty || value.length < 6) {
                            return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'كلمة المرور',
                          hintStyle: TextStyles.font14LightGrayRegular,
                          prefixIcon: const Icon(Icons.lock_outline, color: ColorsManager.lightBlue),
                          filled: true,
                          fillColor: ColorsManager.mainDarkBlue,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ColorsManager.darkGray, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ColorsManager.lightBlue, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ColorsManager.errorRed, width: 1),
                          ),
                        ),
                      ),

                      // 3. تصميم خيار "تذكرني"
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Theme(
                            data: ThemeData(unselectedWidgetColor: ColorsManager.darkGray),
                            child: Checkbox(
                              value: _isRememberMeChecked,
                              activeColor: ColorsManager.neonBlue,
                              checkColor: ColorsManager.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (value) {
                                setState(() {
                                  _isRememberMeChecked = value ?? false;
                                });
                              },
                            ),
                          ),
                          const Text('تذكرني', style: TextStyles.font14LightGrayRegular),
                        ],
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorsManager.neonBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (cubit.formKey.currentState!.validate()) {
                            // 4. حفظ أو مسح الإيميل بناءً على اختيار المستخدم
                            final prefs = await SharedPreferences.getInstance();
                            if (_isRememberMeChecked) {
                              await prefs.setString('saved_email', cubit.emailController.text);
                            } else {
                              await prefs.remove('saved_email');
                            }

                            cubit.emitLoginStates();
                          }
                        },
                        child: state is AuthLoading
                            ? const CircularProgressIndicator(color: ColorsManager.white)
                            : const Text('تسجيل الدخول', style: TextStyles.font18WhiteMedium),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'ليس لديك حساب؟',
                            style: TextStyles.font14LightGrayRegular,
                          ),
                          TextButton(
                            onPressed: () {
                              context.push(Routes.signUp);
                            },
                            child: const Text(
                              'إنشاء حساب جديد',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: ColorsManager.lightBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}