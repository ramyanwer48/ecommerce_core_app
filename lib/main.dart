import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // سطر إجباري لضمان تهيئة التطبيق قبل الاتصال بالسحابة
  WidgetsFlutterBinding.ensureInitialized();

  // كود الاتصال بقاعدة البيانات بناءً على المنصة (أندرويد أو ويندوز)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const EcommerceApp());
}

class EcommerceApp extends StatelessWidget {
  const EcommerceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Ecommerce Core App',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'تم تهيئة المشروع والاتصال بنجاح! 🚀',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}