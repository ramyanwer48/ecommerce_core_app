import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class PaymobManager {
  // 👈 مفتاح التحويل السحري: خليه false دلوقتي، ولما البنك يوافق خليه true بس!
  static const bool isLiveMode = false;

  static Future<String> getPaymentKey({
    required double amount,
    required Map<String, dynamic> billingData,
    required String phone,
    required String address,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createSecurePaymobOrder');

      final response = await callable.call({
        'totalAmount': amount,
        'billingData': billingData,
        'phone': phone,
        'address': address,
        'items': items,
        'isLive': isLiveMode, // 👈 بنبعت حالة التطبيق (تيست ولا حقيقي) للسيرفر
      });

      final String paymentToken = response.data['paymentToken'];
      return paymentToken;
    } catch (e) {
      debugPrint('Secure Paymob Error: $e');
      throw Exception('حدث خطأ أثناء إعداد الدفع عبر السيرفر الآمن');
    }
  }
}