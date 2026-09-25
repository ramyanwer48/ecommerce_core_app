import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AiImageService {
  static Future<String> generateAndUploadImage(String productName) async {
    try {
      // 1. تنظيف اسم المنتج من أي رموز خاصة قد تعطل السيرفر المجاني
      String safeName = productName.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '');

      // 2. صياغة أمر الرسم وتشفيره ليكون آمناً 100% كـ URL
      final prompt = "professional product photography of $safeName, clean white background, studio lighting";
      final encodedPrompt = Uri.encodeComponent(prompt);

      // 3. استخدام الرابط المباشر البسيط جداً (بدون بارامترات معقدة)
      final aiUrl = 'https://image.pollinations.ai/prompt/$encodedPrompt';

      // 4. الاتصال بالسيرفر بمهلة 20 ثانية لتجنب التعليق
      final response = await http.get(Uri.parse(aiUrl)).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('السيرفر مشغول حالياً (كود ${response.statusCode}). جرب مرة أخرى بعد قليل.');
      }

      // 5. حفظ الصورة محلياً في ذاكرة التخزين المؤقت
      final documentDirectory = await getTemporaryDirectory();
      final file = File('${documentDirectory.path}/ai_product_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.bodyBytes);

      // 6. رفع الصورة إلى Firebase Storage
      String fileName = 'products_images/ai_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;

      // 7. جلب الرابط الدائم
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 8. تنظيف الملف المؤقت
      if (file.existsSync()) {
        file.deleteSync();
      }

      return downloadUrl;

    } catch (e) {
      throw Exception('${e.toString()}');
    }
  }
}