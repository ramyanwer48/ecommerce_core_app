import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theming/colors.dart';
import '../logic/auth_cubit.dart';
import '../logic/auth_state.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF0D1B2A);
    final Color brandOrange = Colors.orange.shade600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryNavy),
      ),
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthSuccess) {
              context.pop();
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
                physics: const BouncingScrollPhysics(), // 👈 سلاسة السكرول
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // 👈 إخفاء الكيبورد بالسحب
                padding: const EdgeInsets.fromLTRB(24.0, 10.0, 24.0, 24.0), // 👈 مسافات ثابتة ومناسبة
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/RAMY_STORE_ERP_PRIMARY_2400x900.png',
                      height: 110,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'إنشاء حساب جديد',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryNavy,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 40),

                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: TextFormField(
                        controller: cubit.nameController,
                        style: const TextStyle(color: primaryNavy, fontFamily: 'Cairo'),
                        validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال الاسم' : null,
                        decoration: InputDecoration(
                          hintText: 'الاسم بالكامل',
                          hintStyle: const TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
                          prefixIcon: Icon(Icons.person_outline, color: brandOrange),
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
                    const SizedBox(height: 40),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (cubit.formKey.currentState!.validate()) {
                          cubit.emitSignUpStates();
                        }
                      },
                      child: state is AuthLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('تسجيل حساب', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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