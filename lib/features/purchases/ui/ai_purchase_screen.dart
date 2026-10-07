import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';
import '../services/ai_invoice_service.dart';

class AiPurchaseScreen extends StatefulWidget {
  const AiPurchaseScreen({super.key});

  @override
  State<AiPurchaseScreen> createState() => _AiPurchaseScreenState();
}

class _AiPurchaseScreenState extends State<AiPurchaseScreen> with SingleTickerProviderStateMixin {
  // 🚀 الألوان الثابتة للهوية
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;
  final Color bgSoftColor = const Color(0xFFF4F7FB);

  bool _isAnalyzing = false;
  File? _selectedFile;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _cropImage(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'تحديد حدود الفاتورة',
          toolbarColor: primaryNavy,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: brandOrange,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'تحديد حدود الفاتورة',
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _selectedFile = File(croppedFile.path);
      });
      _simulateAiParsing();
    }
  }

  Future<void> _captureFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      await _cropImage(photo.path);
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      await _cropImage(photo.path);
    }
  }

  Future<void> _simulateAiParsing() async {
    if (_selectedFile == null) return;
    setState(() => _isAnalyzing = true);
    HapticFeedback.heavyImpact();

    try {
      final extractedData = await AiInvoiceService.analyzeInvoice(_selectedFile!);
      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      if (extractedData != null) {
        context.push(Routes.invoiceReview, extra: extractedData);
      } else {
        _showErrorDialog("⚠️ الخدمة نجحت ولكنها أعادت بيانات فارغة (Null).");
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      debugPrint("❌ AI Parsing Error StackTrace: $stackTrace");
      _showErrorDialog("❌ خطأ تقني صريح:\n${e.toString()}");
    }
  }

  void _showErrorDialog(String errorMsg) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red),
              const SizedBox(width: 8),
              const Text('عذراً، حدث خطأ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(errorMsg, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.5, color: Colors.grey.shade700)),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgSoftColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('الفاتورة الذكية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          // 🚀 السحر هنا: إضافة علامة X على الشمال للخروج من الشاشة
          actions: [
            Directionality(
              textDirection: TextDirection.ltr, // عشان الأيقونة تبان على الشمال في وضع الـ RTL
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: primaryNavy, size: 28),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    // لو الشاشة دي مفتوحة كأنها رئيسية (مثلاً من الـ Bottom Nav)، ممكن نوديه للرئيسية
                    context.go(Routes.home);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: _isAnalyzing ? _buildAnalyzingState() : _buildUploadState(),
          ),
        ),
      ),
    );
  }

  // 🚀 واجهة الرفع بهوية التطبيق (كارت كحلي، إطار برتقالي)
  Widget _buildUploadState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: primaryNavy,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: brandOrange, width: 2),
        boxShadow: [
          BoxShadow(color: brandOrange.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandOrange.withOpacity(0.15),
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandOrange,
                  boxShadow: [BoxShadow(color: brandOrange.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: const Icon(Icons.document_scanner_rounded, size: 35, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 32),

          const Text(
            'مسح البيان الذكي',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.white),
          ),
          const SizedBox(height: 12),

          Text(
            'صور الفاتورة وسيقوم الذكاء الاصطناعي\nباستخراج الأصناف والأسعار في ثوانٍ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white70, fontFamily: 'Cairo', height: 1.6),
          ),
          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                _captureFromCamera();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: brandOrange,
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.camera_alt_rounded, size: 24, color: Colors.white),
              label: const Text('التقاط بالكاميرا', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.white)),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                _pickFromGallery();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: Icon(Icons.photo_library_rounded, size: 24, color: primaryNavy),
              label: Text('اختيار من الاستوديو', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: primaryNavy)),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 واجهة التحميل بنفس الستايل (كارت كحلي بإطار برتقالي)
  Widget _buildAnalyzingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      decoration: BoxDecoration(
        color: primaryNavy,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: brandOrange, width: 2),
        boxShadow: [
          BoxShadow(color: brandOrange.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.5),
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: brandOrange.withOpacity((1.0 - _pulseController.value) * 0.3)),
                    ),
                  ),
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(color: brandOrange, shape: BoxShape.circle, boxShadow: [BoxShadow(color: brandOrange.withOpacity(0.5), blurRadius: 20)]),
                    child: const Icon(Icons.auto_awesome, size: 40, color: Colors.white),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 40),

          const Text(
            'لحظات من السحر...',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.white),
          ),
          const SizedBox(height: 12),

          Text(
            'الذكاء الاصطناعي يقرأ فاتورتك الآن\nويستخرج البيانات بدقة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white70, fontFamily: 'Cairo', fontWeight: FontWeight.w600, height: 1.5),
          ),
          const SizedBox(height: 30),

          SizedBox(
            width: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(brandOrange),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}