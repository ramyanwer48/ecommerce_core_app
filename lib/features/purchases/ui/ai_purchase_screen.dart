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
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandBlue = const Color(0xFF1E5B70);
  final Color brandPurple = Colors.deepPurple;

  bool _isAnalyzing = false;
  File? _selectedFile;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ✂️ دالة اقتصاص الصورة
  Future<void> _cropImage(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'تعديل الفاتورة',
          toolbarColor: primaryNavy,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'تعديل الفاتورة',
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

  // 📸 التقاط صورة من الكاميرا
  Future<void> _captureFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      await _cropImage(photo.path);
    }
  }

  // 🖼️ اختيار صورة من الاستوديو
  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);

    if (photo != null) {
      await _cropImage(photo.path);
    }
  }

  // 🤖 الدالة التشخيصية الدقيقة للاتصال بالـ Cloud Function
  Future<void> _simulateAiParsing() async {
    if (_selectedFile == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    HapticFeedback.heavyImpact();

    try {
      final extractedData = await AiInvoiceService.analyzeInvoice(_selectedFile!);

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
      });

      if (extractedData != null) {
        context.push(Routes.invoiceReview, extra: extractedData);
      } else {
        _showErrorDialog("⚠️ الخدمة نجحت ولكنها أعادت بيانات فارغة (Null).");
      }
    } catch (e, stackTrace) {
      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
      });

      debugPrint("❌ AI Parsing Error StackTrace: $stackTrace");
      _showErrorDialog("❌ خطأ تقني صريح:\n${e.toString()}");
    }
  }

  void _showErrorDialog(String errorMsg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تشخيص خطأ الـ AI', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red)),
        content: SingleChildScrollView(
          child: Text(
            errorMsg,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryNavy),
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF102841),
        appBar: AppBar(
          title: const Text('إدخال مشتريات (AI)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 17)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _isAnalyzing ? _buildAnalyzingState() : _buildUploadState(),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A54),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.document_scanner_rounded, size: 70, color: Colors.cyanAccent),
          const SizedBox(height: 16),
          const Text(
            'مسح البيان والمطابقة الذكية',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'سيتم قراءة الأصناف، الكميات، والأسعار تلقائياً\nحتى للفواتير المكتوبة بخط اليد.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white70, fontFamily: 'Cairo', height: 1.5),
          ),
          const SizedBox(height: 40),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _captureFromCamera,
                  style: ElevatedButton.styleFrom( // 👈 تم التصحيح هنا بنجاح
                    backgroundColor: const Color(0xFF1B6A7F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text('الكاميرا', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C4C66),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  label: const Text('الاستوديو', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.1),
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyanAccent.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.document_scanner_rounded, size: 60, color: Colors.cyanAccent),
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        const Text(
          'جاري استخراج البيانات...',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'يتم الآن تحليل الفاتورة ومطابقة الأصناف',
          style: TextStyle(fontSize: 14, color: Colors.white70, fontFamily: 'Cairo'),
        ),
        const SizedBox(height: 30),
        const CircularProgressIndicator(color: Colors.cyanAccent),
      ],
    );
  }
}