import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AiInvoiceService {
  static Future<Map<String, dynamic>?> analyzeInvoice(File imageFile) async {
    try {
      // 1. تحويل الصورة إلى Base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 2. إعداد الاتصال بالدالة السحابية
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'analyzeInvoice',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );

      // 3. التنفيذ واستقبال الرد الخام
      final result = await callable.call({
        'imageBase64': base64Image,
      });

      // 🔍 تتبع هندسي دقيق لمعرفة نوع وداتا الرد القادم من السيرفر
      debugPrint("🟢 [AI_DEBUG] Server Response Type: ${result.data?.runtimeType}");
      debugPrint("🟢 [AI_DEBUG] Server Response Data: ${result.data}");

      if (result.data == null) {
        debugPrint("🔴 [AI_DEBUG] Error: result.data is null");
        return null;
      }

      // 4. معالجة آمنة للبيانات بناءً على شكلها القادم
      if (result.data is Map) {
        // تحويل آمن للمفتاح والقيمة لتجنب أخطاء الـ Type Casting
        return Map<String, dynamic>.from(
          (result.data as Map).map((key, value) => MapEntry(key.toString(), value)),
        );
      } else if (result.data is String) {
        // تنظيف النص من علامات Markdown التي يضيفها الذكاء الاصطناعي (مثل ```json و ```)
        String rawString = result.data as String;
        String cleanedString = rawString.replaceAll(RegExp(r'```(?:json)?'), '').trim();

        final decoded = jsonDecode(cleanedString);
        if (decoded is Map) {
          return Map<String, dynamic>.from(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      }

      debugPrint("🔴 [AI_DEBUG] Error: result.data is neither Map nor String");
      return null;

    } catch (e, stackTrace) {
      // 🔴 طباعة الخطأ الحقيقي بالكامل على الـ Console لو حدث استثناء
      debugPrint("💥 [AI_EXCEPTION] Error: $e");
      debugPrint("💥 [AI_EXCEPTION] StackTrace: $stackTrace");
      return null;
    }
  }
}