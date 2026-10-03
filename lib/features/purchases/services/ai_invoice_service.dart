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

      // 👈 2. إعداد الـ Prompt الدقيق (مضاف إليه تاريخ الفاتورة)
      const String promptText = '''
قم بتحليل صورة الفاتورة المرفقة واستخراج البيانات منها بصيغة JSON فقط كالتالي:
{
  "supplierName": "اسم المورد",
  "invoiceNumber": "رقم الفاتورة",
  "invoiceDate": "YYYY-MM-DD", 
  "items": [
    {
      "name": "اسم المنتج",
      "qty": 5,
      "price": 100.5
    }
  ]
}
ملاحظات هامة: 
1. ابحث بدقة عن "تاريخ الفاتورة" الفعلي المكتوب في الورقة، وإذا لم تجده اتركه فارغاً.
2. لا تضف أي نصوص أو شروحات خارج هيكل الـ JSON نهائياً.
''';

      // 3. إعداد الاتصال بالدالة السحابية
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'analyzeInvoice',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );

      // 4. التنفيذ وإرسال الصورة + الأوامر للسيرفر
      final result = await callable.call({
        'imageBase64': base64Image,
        'prompt': promptText, // 👈 إرسال الـ Prompt من التطبيق لمرونة التعديل
      });

      // 🔍 تتبع هندسي دقيق لمعرفة نوع وداتا الرد القادم من السيرفر
      debugPrint("🟢 [AI_DEBUG] Server Response Type: ${result.data?.runtimeType}");
      debugPrint("🟢 [AI_DEBUG] Server Response Data: ${result.data}");

      if (result.data == null) {
        debugPrint("🔴 [AI_DEBUG] Error: result.data is null");
        return null;
      }

      // 5. معالجة آمنة للبيانات بناءً على شكلها القادم
      if (result.data is Map) {
        return Map<String, dynamic>.from(
          (result.data as Map).map((key, value) => MapEntry(key.toString(), value)),
        );
      } else if (result.data is String) {
        // تنظيف النص من علامات Markdown التي يضيفها الذكاء الاصطناعي
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
      debugPrint("💥 [AI_EXCEPTION] Error: $e");
      debugPrint("💥 [AI_EXCEPTION] StackTrace: $stackTrace");
      return null;
    }
  }
}