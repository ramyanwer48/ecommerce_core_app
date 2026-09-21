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

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');

    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _isRememberMeChecked = true;
      });
      Future.microtask(() {
        if (mounted) {
          context.read<AuthCubit>().emailController.text = savedEmail;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF0D1B2A);
    final Color brandOrange = Colors.orange.shade600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) async {
            if (state is AuthSuccess) {
              final prefs = await SharedPreferences.getInstance();
              bool hasAskedBiometric = prefs.getBool('has_asked_biometric') ?? false;

              if (!hasAskedBiometric && mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: AlertDialog(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Column(
                        children: [
                          Icon(Icons.fingerprint, size: 60, color: brandOrange),
                          const SizedBox(height: 12),
                          const Text(
                            'تفعيل البصمة',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                      content: const Text(
                        'فعل البصمة الآن لدخول أسرع وأكثر أماناً.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black87, height: 1.5, fontSize: 16, fontFamily: 'Cairo'),
                      ),
                      actionsAlignment: MainAxisAlignment.spaceEvenly,
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandOrange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            prefs.setBool('isBiometricEnabled', true);
                            prefs.setBool('has_asked_biometric', true);
                            Navigator.pop(dialogContext);
                            context.go(Routes.home);
                          },
                          child: const Text('تفعيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
                        ),
                        TextButton(
                          onPressed: () {
                            prefs.setBool('isBiometricEnabled', false);
                            prefs.setBool('has_asked_biometric', true);
                            Navigator.pop(dialogContext);
                            context.go(Routes.home);
                          },
                          child: const Text('لا، شكراً', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                if (mounted) context.go(Routes.home);
              }
            } else if (state is AuthFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage), backgroundColor: ColorsManager.errorRed),
              );
            }
          },
          builder: (context, state) {
            final cubit = context.read<AuthCubit>();
            return Form(
              key: cubit.formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(), // 👈 سلاسة في النزول والطلوع
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // 👈 إخفاء الكيبورد بالسحب
                padding: const EdgeInsets.fromLTRB(24.0, 70.0, 24.0, 24.0), // 👈 مسافة ثابتة لا تسبب تقطيع
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/RAMY_STORE_ERP_PRIMARY_2400x900.png',
                      height: 110,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'مرحباً بك مجدداً',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryNavy,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 50),

                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: TextFormField(
                        controller: cubit.emailController,
                        style: const TextStyle(color: primaryNavy, fontFamily: 'Cairo'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال البريد الإلكتروني' : null,
                        decoration: InputDecoration(
                          hintText: 'البريد الإلكتروني',
                          hintStyle: const TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
                          prefixIcon: Icon(Icons.email_outlined, color: brandOrange),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: brandOrange, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: TextFormField(
                        controller: cubit.passwordController,
                        obscureText: true,
                        style: const TextStyle(color: primaryNavy, fontFamily: 'Cairo'),
                        validator: (value) => (value == null || value.isEmpty || value.length < 6) ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null,
                        decoration: InputDecoration(
                          hintText: 'كلمة المرور',
                          hintStyle: const TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
                          prefixIcon: Icon(Icons.lock_outline, color: brandOrange),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: brandOrange, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        children: [
                          Theme(
                            data: ThemeData(unselectedWidgetColor: Colors.grey.shade400),
                            child: Checkbox(
                              value: _isRememberMeChecked,
                              activeColor: brandOrange,
                              checkColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (value) {
                                setState(() { _isRememberMeChecked = value ?? false; });
                              },
                            ),
                          ),
                          const Text('تذكرني', style: TextStyle(color: primaryNavy, fontWeight: FontWeight.w600, fontFamily: 'Cairo', fontSize: 15)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (cubit.formKey.currentState!.validate()) {
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
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('تسجيل الدخول', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    ),

                    const SizedBox(height: 40),

                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'ليس لديك حساب؟',
                            style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 15),
                          ),
                          TextButton(
                            onPressed: () {
                              context.push(Routes.signUp);
                            },
                            child: Text(
                              'إنشاء حساب جديد',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: brandOrange,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}