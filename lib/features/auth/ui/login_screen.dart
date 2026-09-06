import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theming/colors.dart';
import '../../../core/theming/styles.dart';
import '../logic/auth_cubit.dart';
import '../logic/auth_state.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthSuccess) {
              context.go(Routes.home);
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
              // --- الحل الجذري هنا: Center + SingleChildScrollView ---
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
                      const SizedBox(height: 30),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorsManager.neonBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          if (cubit.formKey.currentState!.validate()) {
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