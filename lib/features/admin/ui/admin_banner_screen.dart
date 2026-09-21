import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class AdminBannerScreen extends StatefulWidget {
  const AdminBannerScreen({super.key});

  @override
  State<AdminBannerScreen> createState() => _AdminBannerScreenState();
}

class _AdminBannerScreenState extends State<AdminBannerScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentBanner();
  }

  // استدعاء بيانات الإعلان الحالية
  Future<void> _loadCurrentBanner() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('banner').get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _titleController.text = data['title'] ?? '';
          _subtitleController.text = data['subtitle'] ?? '';
          _isActive = data['isActive'] ?? true;
        });
      }
    } catch (e) {
      debugPrint("Error loading banner: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // تحديث بيانات الإعلان
  Future<void> _saveBanner() async {
    // 👈 لا نطلب النصوص إلا إذا كان الإعلان سيتم تفعيله
    if (_isActive && (_titleController.text.trim().isEmpty || _subtitleController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال العنوان والتفاصيل قبل التفعيل'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('banner').set({
        'title': _titleController.text.trim(),
        'subtitle': _subtitleController.text.trim(),
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الإعلان بنجاح 🚀'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint("Error saving banner: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF0D1B2A);
    final Color brandOrange = Colors.orange.shade600;

    return Scaffold(
      backgroundColor: Colors.white,

      // 👈 تم تغليف الـ AppBar بـ LTR لإجبار السهم على التواجد في اليسار
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            title: const Text(
                'إدارة إعلان المتجر',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)
            ),
            backgroundColor: primaryNavy,
            foregroundColor: Colors.white,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back), // 👈 سهم الرجوع أصبح في اليسار ويشير لليسار
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),

      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: brandOrange))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تحكم في البانر الإعلاني الذي يظهر للعملاء في الصفحة الرئيسية للمتجر.',
                style: TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 30),

              SwitchListTile(
                title: const Text('تفعيل الإعلان', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                subtitle: const Text('إظهار أو إخفاء البانر من واجهة المتجر', style: TextStyle(fontSize: 12, fontFamily: 'Cairo')),
                value: _isActive,
                activeColor: brandOrange,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              const Divider(height: 40),

              TextField(
                controller: _titleController,
                style: const TextStyle(color: primaryNavy, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'عنوان الإعلان',
                  hintText: 'مثال: خصم 50% على الأجهزة',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: brandOrange, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _subtitleController,
                maxLines: 3,
                style: const TextStyle(color: primaryNavy, fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  labelText: 'تفاصيل الإعلان',
                  hintText: 'مثال: تسوق الآن واستمتع بأقوى العروض الحصرية...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: brandOrange, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveBanner,
                child: const Text(
                  'حفظ التحديثات',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}