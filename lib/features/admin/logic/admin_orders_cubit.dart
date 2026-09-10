import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../data/repos/admin_orders_repo.dart';
import 'admin_orders_state.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;

class AdminOrdersCubit extends Cubit<AdminOrdersState> {
  final AdminOrdersRepo _repo;

  AdminOrdersCubit(this._repo) : super(AdminOrdersInitial());

  Future<void> fetchAllOrders() async {
    emit(AdminOrdersLoading());
    try {
      final orders = await _repo.getAllOrders();
      emit(AdminOrdersLoaded(orders));
    } catch (e) {
      emit(AdminOrdersError(e.toString()));
    }
  }

  Future<void> updateStatus(String orderId, String userId, String newStatus) async {
    try {
      await _repo.updateOrderStatus(orderId, newStatus);
      emit(AdminOrderStatusUpdated());

      // 👈 تم تمرير orderId هنا
      await _notifyUser(userId, newStatus, orderId);

      fetchAllOrders();
    } catch (e) {
      emit(AdminOrdersError(e.toString()));
    }
  }

  // 👈 إضافة orderId كمعامل (Parameter)
  Future<void> _notifyUser(String userId, String status, String orderId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'];

      if (fcmToken != null) {
        // 👈 تمرير orderId هنا
        await _sendPushNotification(fcmToken, status, orderId);
      } else {
        print('⚠️ هذا العميل لم يسجل الدخول من قبل أو لا يمتلك fcmToken');
      }
    } catch (e) {
      print('❌ خطأ أثناء البحث عن بيانات العميل: $e');
    }
  }

  // 👈 إضافة orderId كمعامل (Parameter)
  Future<void> _sendPushNotification(String fcmToken, String status, String orderId) async {
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "ecommerce-core-app-b3f08",
      "private_key_id": "a8f938139659f5023ca40f6f6dcbb2020284aa59",
      "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDYvJ5J9VjyDxj9\ngwfvI9D3+hX1Dq0pG7Rjg25hFp58azd4KhiPCVC82153QVoJ8a8vn8rX7H1tCUzS\nQjWbhnHAeblsVsKvPQ4LVltHrSRwT/oTivyObLhTUrD2LffbWuqI8IYiCyaTt8QW\noc2A2E1Zfd3dduAeN0klLEqPPe1T5dAAJmMT31f140O31KfKxQlf8V1xW4D/8TDb\nC36+agnjJ9Pc7DdR3S6Cqxv3x2Fh68KSCMhCx3RqF76bxHHDhCVYv+Yy2O3QLWu0\nv8oPO9wr7RSXdJ/59xRwGW9gMSJc+K2YTsC/xZDWmW+z6SU/CSJqScbemBRWqpMc\nmzVeuMGPAgMBAAECggEABudPJWzutdscQSr0zD24UMXDAEjE5DvRLaBImkgVqUHj\nBO1WVewGidV091h6DToJCfvNgr4yKpByxXm9amRIaEiYSuaikeFgeqT4CFrv/7HU\ndd3l+IVnA6RtJZJGRFLriIwcwaXYRzlBwjTKLnH1WMXlFMJOFjhNmKUGBPUEg7kN\nrqVjvD3d0rCmDbBsoJdaWd8hM2rDJkoDZI7u7bCfw/PD+s277KBsFwFcWwV1m8eI\nnxBfqWdAyYcnLAaQ5Eif1X/S/jmguEGiSHwyL6AuxECHy/YUYJ4obBaaDk365wYS\nLvxSG2FCxVZvcJ3ByiJ6HfuOJtA0R0OHBWkPZ1DMOQKBgQD/PPc0BS/TAsVdX0mJE\n0GcpdjXJ/XmVTFjglfPa8PdruC4Eo3y6mh7bA9QA8xVKmRQ0RN6UfJzvYiirspq\nhgHo7KXXX3Zp2EfMMas8w7Zw4xSPzwHAWeycLo3b4ptDI57LLMZF8f3TOIetvEt9\n8tHJcxZLiTJ1nooAZrX4KgQIZwKBgQDZYjuVoA5989soGRUq+nlv402thiq7OF9T\n3jYMFLZN+xCbE612FpjZqnNn1hSZ5F2D8/mRqZd6WsTcIjt2y4SNOTBg3MBmLqvb\ndz+jFaOpaDQuohRH1ykvUcqXu6Ja9kXuTwUgZb2qiSKGTJPasei1MR/3ZQzxn87d\nCOjBygzkmQKBgQCwzjSXzngAfczmD1nLIJG0x5XcBQxrz9v0iJf3UTlO2RNFr2Sx\nPvu9c29wCBGFdWYkLZCGjTmcP1DlEJubCtVL2pJPDQvj6jRiGI37+77nmAXoUIdw\nDVrAHeeax/Cxo30eVRfL4APqSyCBkwvgZVI5cAWjsZhIrdf+yyeGjuRYRQKBgDCB\nAaiGGRWzdqAA0L9ROg1kG23vdNNnZaXR/B8/89l8fp0Li/XAXwSaSrvNgbVAxjju\nFC6TN7BeVnSD0t7T1FSqgQfr2aYzHbePaQybhHQFQzdwhLPu50qepmSqwjQnpTzi\nNtOev+4wQRrUNV1juvfK6UYLLxMuxDp/hWfQDIZpAoGBAP3Nwf4024n+6EbLFweK\nFwdYLPphXMvSLEKFaO8TzhFzb5SsgmPBZPC9XDGZNA5m4SdwTOwYdl98EjFo5ko/\n8l3C4Y/w3mFsV1AuENEJ93Z/+tnTKYl5D2OVNTLMlDPpI+UB61UIarV/0U5OuSI8\nH8NaWdSs+9KSWGuD+WaqKiCd\n-----END PRIVATE KEY-----\n",
      "client_email": "firebase-adminsdk-fbsvc@ecommerce-core-app-b3f08.iam.gserviceaccount.com",
      "client_id": "102996693595293677739",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40ecommerce-core-app-b3f08.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    };

    String bodyMsg = 'تم تحديث حالة طلبك إلى: $status';
    if (status == 'جاري التوصيل') bodyMsg = 'مندوبنا في الطريق إليك 🚚';
    if (status == 'تم التسليم') bodyMsg = 'شكراً لتسوقك من رامي ستور! نأمل أن يعجبك المنتج ✅';

    try {
      final accountCredentials = auth.ServiceAccountCredentials.fromJson(serviceAccountJson);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await auth.clientViaServiceAccount(accountCredentials, scopes);

      final projectId = serviceAccountJson['project_id'];
      final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

      final response = await authClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {
              'title': 'تحديث حالة الطلب 📦',
              'body': bodyMsg,
            },
            // 🚀 السر هنا: البايلود المخفي (Data Payload) للـ Deep Linking
            'data': {
              'type': 'order_update', // عشان التطبيق يعرف نوع الإشعار
              'orderId': orderId,     // الـ ID اللي هنفتح بيه الشاشة
            },
          }
        }),
      );

      print('✅ حالة إرسال الإشعار بالنظام الجديد: ${response.statusCode}');
      authClient.close();

    } catch (e) {
      print('❌ فشل الاتصال بسيرفر الإشعارات v1: $e');
    }
  }
}