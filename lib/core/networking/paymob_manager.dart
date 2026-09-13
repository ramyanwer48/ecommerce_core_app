import 'package:dio/dio.dart';
import '../constants/paymob_constants.dart';

class PaymobManager {
  static late Dio dio;

  // 1. دالة التهيئة (تستدعى مرة واحدة عند فتح التطبيق)
  static void init() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://accept.paymob.com/api/',
        receiveDataWhenStatusError: true,
      ),
    );
  }

  // 2. دالة جلب مفتاح الدفع للبطاقات البنكية (Online Card)
  static Future<String> getPaymentKey({
    required double amount,
    required Map<String, dynamic> billingData,
  }) async {
    try {
      String amountInCents = (amount * 100).toInt().toString();
      String authToken = await _getAuthToken();
      String orderId = await _getOrderId(
        authToken: authToken,
        amountInCents: amountInCents,
      );

      String finalPaymentKey = await _getPaymentKey(
        authToken: authToken,
        orderId: orderId,
        amountInCents: amountInCents,
        billingData: billingData,
        integrationId: PaymobConstants.integrationId,
      );

      return finalPaymentKey;
    } catch (e) {
      print('Paymob Card Error: $e');
      throw Exception('حدث خطأ أثناء الاتصال ببوابة الدفع للبطاقة');
    }
  }

  // 3. دالة الدفع بالمحافظ الإلكترونية (Mobile Wallets)
  static Future<String> payWithWallet({
    required double amount,
    required String walletPhoneNumber,
    required Map<String, dynamic> billingData,
  }) async {
    try {
      String amountInCents = (amount * 100).toInt().toString();
      String authToken = await _getAuthToken();
      String orderId = await _getOrderId(
        authToken: authToken,
        amountInCents: amountInCents,
      );

      // جلب مفتاح الدفع باستخدام معرف المحافظ
      String paymentKey = await _getPaymentKey(
        authToken: authToken,
        orderId: orderId,
        amountInCents: amountInCents,
        billingData: billingData,
        integrationId: PaymobConstants.walletIntegrationId,
      );

      // تنفيذ طلب الدفع للمحفظة
      final response = await dio.post(
        'acceptance/payments/pay',
        data: {
          "source": {
            "identifier": walletPhoneNumber,
            "subtype": "WALLET"
          },
          "payment_token": paymentKey
        },
      );

      return response.data['redirect_url'] ?? '';
    } catch (e) {
      print('Paymob Wallet Error: $e');
      throw Exception('حدث خطأ أثناء تنفيذ الدفع بالمحفظة الإلكترونية');
    }
  }

  // ---------------- الدوال الفرعية (Private) ----------------

  static Future<String> _getAuthToken() async {
    final response = await dio.post(
      'auth/tokens',
      data: {'api_key': PaymobConstants.apiKey},
    );
    return response.data['token'];
  }

  static Future<String> _getOrderId({
    required String authToken,
    required String amountInCents,
  }) async {
    final response = await dio.post(
      'ecommerce/orders',
      data: {
        'auth_token': authToken,
        'delivery_needed': 'false',
        'amount_cents': amountInCents,
        'currency': 'EGP',
        'items': [],
      },
    );
    return response.data['id'].toString();
  }

  static Future<String> _getPaymentKey({
    required String authToken,
    required String orderId,
    required String amountInCents,
    required Map<String, dynamic> billingData,
    required String integrationId,
  }) async {
    final response = await dio.post(
      'acceptance/payment_keys',
      data: {
        'expiration': 3600,
        'auth_token': authToken,
        'order_id': orderId,
        'integration_id': integrationId,
        'amount_cents': amountInCents,
        'currency': 'EGP',
        'billing_data': billingData,
        'lock_order_when_paid': 'false',
      },
    );
    return response.data['token'];
  }
}