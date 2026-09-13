import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// لم نعد بحاجة لاستدعاء PaymobConstants هنا لأن الرابط الحديث لا يحتاج iframeId

class PaymobWebviewScreen extends StatefulWidget {
  final String? paymentKey;
  final String? url;

  const PaymobWebviewScreen({
    super.key,
    this.paymentKey,
    this.url,
  });

  @override
  State<PaymobWebviewScreen> createState() => _PaymobWebviewScreenState();
}

class _PaymobWebviewScreenState extends State<PaymobWebviewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    // تحديد الرابط المطلوب تحميله (رابط بيموب الحديث أو رابط محفظة)
    final Uri uriToLoad;
    if (widget.url != null && widget.url!.isNotEmpty) {
      uriToLoad = Uri.parse(widget.url!);
    } else if (widget.paymentKey != null) {
      // الرابط الحديث (Unified Checkout)
      uriToLoad = Uri.parse(
        'https://accept.paymob.com/unifiedcheckout/?payment_token=${widget.paymentKey}',
      );
    } else {
      throw Exception('يجب تمرير paymentKey أو url لشاشة الـ WebView');
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            print('Paymob Redirect URL: ${request.url}');

            if (request.url.contains('success=true')) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            } else if (request.url.contains('success=false')) {
              Navigator.pop(context, false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(uriToLoad);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدفع الإلكتروني'),
        centerTitle: true,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}