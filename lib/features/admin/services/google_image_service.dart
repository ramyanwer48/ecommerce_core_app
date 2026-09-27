import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

class GoogleImageService {
  static Future<List<String>> fetchImageUrls(String productName) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('searchGoogleImages');
      final result = await callable.call({'query': productName});

      final List<dynamic> imagesData = result.data['images'] ?? [];
      return imagesData.map((e) => e['link'].toString()).toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception('خطأ في الاتصال بالخادم: ${e.message}');
    } catch (e) {
      throw Exception('تعذر جلب الصور: $e');
    }
  }

  // الدالة القديمة لرفع صورة واحدة
  static Future<String> downloadAndUploadSelectedImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw Exception('فشل تحميل الصورة المحددة');

      final documentDirectory = await getTemporaryDirectory();
      final file = File('${documentDirectory.path}/official_img_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.bodyBytes);

      String fileName = 'products_images/official_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      if (file.existsSync()) file.deleteSync();

      return downloadUrl;
    } catch (e) {
      throw Exception('فشل في معالجة ورفع الصورة: $e');
    }
  }

  // 👈 الدالة الجديدة: معالجة ورفع مجموعة صور (Multi-Upload) دفعة واحدة
  static Future<List<String>> downloadAndUploadMultipleImages(List<String> imageUrls) async {
    List<String> uploadedUrls = [];
    for (String url in imageUrls) {
      try {
        String finalUrl = await downloadAndUploadSelectedImage(url);
        uploadedUrls.add(finalUrl);
      } catch (e) {
        print('فشل رفع إحدى الصور، سيتم تخطيها: $e');
      }
    }
    return uploadedUrls;
  }
}