import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/routing/routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;

  final Color primaryNavy = const Color(0xFF000826);
  final Color brandOrange = Colors.orange.shade600;

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      context.go(Routes.login);
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 70);

      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      final file = File(pickedFile.path);
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) throw Exception('المستخدم غير مسجل الدخول');

      final storageRef = FirebaseStorage.instance.ref().child('user_profiles/${user.uid}.jpg');
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);

      setState(() => _isUploading = false);

      if (mounted) {
        // 🚀 الرسالة الجديدة (كبسولة شيك، سريعة، ولونها أخضر فخم)
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('تم تحديث صورتك', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              backgroundColor: const Color(0xFF10B981), // أخضر فخم
              behavior: SnackBarBehavior.floating,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 24, left: 60, right: 60), // ملمومة في النص
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // شكل الكبسولة
              duration: const Duration(milliseconds: 1500), // سريعة جداً (ثانية ونص)
            )
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('حدث خطأ، حاول مرة أخرى', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 24, left: 60, right: 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              duration: const Duration(milliseconds: 2000),
            )
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text('تغيير الصورة الشخصية', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: brandOrange.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.camera_alt_rounded, color: brandOrange)),
                title: const Text('التقاط صورة بالكاميرا', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryNavy.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.photo_library_rounded, color: primaryNavy)),
                title: const Text('اختيار من الاستوديو', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: brandOrange.withOpacity(0.5), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      child: _isUploading
                          ? CircularProgressIndicator(color: brandOrange)
                          : user?.photoURL == null
                          ? Icon(Icons.person_rounded, size: 50, color: primaryNavy.withOpacity(0.5))
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showImageSourceDialog();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: brandOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                user?.email ?? 'مستخدم غير معروف',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 40),

              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: brandOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.receipt_long_rounded, color: brandOrange),
                ),
                title: const Text('سجل الطلبات', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                tileColor: Colors.white,
                onTap: () => context.push(Routes.orders),
              ),

              const SizedBox(height: 16),

              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: primaryNavy.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.location_on_rounded, color: primaryNavy),
                ),
                title: const Text('عناويني المحفوظة', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                tileColor: Colors.white,
                onTap: () => context.push('/addresses'),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  label: const Text('تسجيل الخروج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
                  onPressed: () => _logout(context),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}