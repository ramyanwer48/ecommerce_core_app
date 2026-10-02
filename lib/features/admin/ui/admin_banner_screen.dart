import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminBannerScreen extends StatelessWidget {
  const AdminBannerScreen({super.key});

  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = const Color(0xFFFB8C00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            title: const Text('إدارة إعلانات المتجر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: primaryNavy,
            foregroundColor: Colors.white,
            centerTitle: true,
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('banners').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: brandOrange));
            }

            final Map<String, Map<String, dynamic>> bannersData = {};
            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                bannersData[doc.id] = doc.data() as Map<String, dynamic>;
              }
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (context, index) {
                final int slotNumber = index + 1;
                final String docId = 'banner_$slotNumber';
                final bool isSlotFilled = bannersData.containsKey(docId);

                final Map<String, dynamic> data = isSlotFilled ? bannersData[docId]! : <String, dynamic>{};

                return _buildBannerSlot(context, slotNumber, docId, isSlotFilled, data);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBannerSlot(BuildContext context, int slotNumber, String docId, bool isFilled, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isFilled ? 3 : 0,
      color: isFilled ? Colors.white : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isFilled ? Colors.transparent : Colors.grey.shade300, width: 1.5, style: isFilled ? BorderStyle.none : BorderStyle.solid),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showBeautifulEditSheet(context, slotNumber, docId, isFilled ? data : null),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isFilled ? brandOrange.withOpacity(0.15) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  image: (isFilled && data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
                      ? DecorationImage(image: NetworkImage(data['imageUrl']), fit: BoxFit.cover)
                      : null,
                ),
                child: (isFilled && data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
                    ? null
                    : Center(
                  child: Text(
                    '$slotNumber',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isFilled ? brandOrange : Colors.grey.shade500),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: isFilled
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        (data['title'] != null && data['title'].toString().isNotEmpty) ? data['title'] : 'بدون عنوان',
                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15, color: primaryNavy)
                    ),
                    const SizedBox(height: 4),
                    Text(
                        (data['subtitle'] != null && data['subtitle'].toString().isNotEmpty) ? data['subtitle'] : 'بدون تفاصيل',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
                        maxLines: 1, overflow: TextOverflow.ellipsis
                    ),
                  ],
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('خانة إعلانية فارغة', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text('اضغط هنا لإضافة إعلان في هذا المكان', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),

              if (isFilled)
                Switch(
                  value: data['isActive'] ?? true,
                  activeColor: brandOrange,
                  onChanged: (val) {
                    FirebaseFirestore.instance.collection('banners').doc(docId).update({'isActive': val});
                  },
                )
              else
                Icon(Icons.add_circle_outline, color: Colors.grey.shade400, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  void _showBeautifulEditSheet(BuildContext context, int slotNumber, String docId, Map<String, dynamic>? currentData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BannerEditSheet(slotNumber: slotNumber, docId: docId, currentData: currentData),
    );
  }
}

// ==========================================
// ويدجت الشاشة المنبثقة
// ==========================================
class _BannerEditSheet extends StatefulWidget {
  final int slotNumber;
  final String docId;
  final Map<String, dynamic>? currentData;

  const _BannerEditSheet({required this.slotNumber, required this.docId, this.currentData});

  @override
  State<_BannerEditSheet> createState() => _BannerEditSheetState();
}

class _BannerEditSheetState extends State<_BannerEditSheet> {
  late TextEditingController titleCtrl;
  late TextEditingController subCtrl;
  late TextEditingController imgCtrl;
  bool _isLoading = false;
  File? _pickedImage;
  bool _removeExistingImage = false; // 👈 متغير جديد لتتبع رغبة المستخدم في حذف الصورة المحفوظة

  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = const Color(0xFFFB8C00);

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.currentData?['title'] ?? '');
    subCtrl = TextEditingController(text: widget.currentData?['subtitle'] ?? '');
    imgCtrl = TextEditingController(text: widget.currentData?['imageUrl'] ?? '');
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    subCtrl.dispose();
    imgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
        imgCtrl.clear();
        _removeExistingImage = true; // نعتبر أن الصورة القديمة سيتم استبدالها
      });
    }
  }

  Future<String?> _uploadImageToStorage(File imageFile) async {
    try {
      final fileName = 'banner_${widget.slotNumber}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('banners/$fileName');
      final uploadTask = await ref.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _saveBanner() async {
    // إزالة قيد إجبارية العنوان (يمكنك الآن حفظ إعلان فارغ أو بصورة فقط)
    if (titleCtrl.text.trim().isEmpty && subCtrl.text.trim().isEmpty && _pickedImage == null && (imgCtrl.text.trim().isEmpty && (_removeExistingImage || widget.currentData?['imageUrl'] == null))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن حفظ إعلان فارغ تماماً', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    String imageUrl = imgCtrl.text.trim();
    if (_removeExistingImage) {
      imageUrl = ''; // تفريغ الرابط في قاعدة البيانات
    }

    if (_pickedImage != null) {
      final uploadedUrl = await _uploadImageToStorage(_pickedImage!);
      if (uploadedUrl != null) {
        imageUrl = uploadedUrl;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفع الصورة', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
        return;
      }
    }

    final data = {
      'title': titleCtrl.text.trim(),
      'subtitle': subCtrl.text.trim(),
      'imageUrl': imageUrl,
      'isActive': widget.currentData?['isActive'] ?? true,
      'createdAt': widget.currentData?['createdAt'] ?? FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('banners').doc(widget.docId).set(data);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteBanner() async {
    setState(() => _isLoading = true);
    await FirebaseFirestore.instance.collection('banners').doc(widget.docId).delete();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // التحقق مما إذا كان هناك صورة محفوظة مسبقاً
    bool hasSavedImage = widget.currentData != null &&
        widget.currentData!['imageUrl'] != null &&
        widget.currentData!['imageUrl'].toString().isNotEmpty &&
        !_removeExistingImage;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(top: 60),
        padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 16 : 32, left: 24, right: 24, top: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      widget.currentData == null ? 'تكوين الخانة رقم ${widget.slotNumber}' : 'تعديل الخانة رقم ${widget.slotNumber}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: primaryNavy),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.black54, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 👈 إضافة زر التفريغ (onClear) لحقل العنوان الرئيسي
              _buildModernTextField(
                controller: titleCtrl,
                label: 'العنوان الرئيسي',
                icon: Icons.title_rounded,
                onClear: () => setState(() => titleCtrl.clear()),
              ),
              const SizedBox(height: 16),

              // 👈 إضافة زر التفريغ (onClear) لحقل العنوان الفرعي
              _buildModernTextField(
                controller: subCtrl,
                label: 'العنوان الفرعي (تفاصيل العرض)',
                icon: Icons.subtitles_rounded,
                maxLines: 2,
                onClear: () => setState(() => subCtrl.clear()),
              ),
              const SizedBox(height: 16),

              // 👈 ويدجت جديد يظهر لمعاينة وحذف الصورة المحفوظة مسبقاً
              if (hasSavedImage && _pickedImage == null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(widget.currentData!['imageUrl'], width: 45, height: 45, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('يوجد صورة محفوظة مسبقاً', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'حذف الصورة الحالية',
                        onPressed: () {
                          setState(() {
                            _removeExistingImage = true;
                            imgCtrl.clear();
                          });
                        },
                      )
                    ],
                  ),
                ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: _buildModernTextField(
                        controller: imgCtrl,
                        label: 'Image URL (Optional)',
                        icon: Icons.link,
                        enabled: _pickedImage == null && !hasSavedImage,
                        onClear: () => setState(() => imgCtrl.clear()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: Text(_pickedImage != null || hasSavedImage ? 'تغيير' : 'رفع صورة', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pickedImage != null ? Colors.green : Colors.grey.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              if (_pickedImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      const Text('تم اختيار صورة من المعرض', style: TextStyle(fontFamily: 'Cairo', color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          _pickedImage = null;
                          _removeExistingImage = false; // التراجع عن الحذف إذا ألغى الاختيار
                        }),
                        child: const Text('إلغاء الصورة المرفوعة', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontSize: 12)),
                      )
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              _isLoading
                  ? Center(child: CircularProgressIndicator(color: brandOrange))
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _saveBanner,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('حفظ ونشر التعديلات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ),
                  if (widget.currentData != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _deleteBanner,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('تفريغ هذه الخانة (حذف الإعلان بالكامل)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 👈 دالة الحقول تم تعديلها لاستقبال onClear (زر التفريغ X)
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
    VoidCallback? onClear,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: enabled ? primaryNavy : Colors.grey),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.grey.shade400),
        // زر الـ (X) للتفريغ السريع
        suffixIcon: onClear != null && controller.text.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear, color: Colors.redAccent, size: 20),
          onPressed: onClear,
        )
            : null,
        filled: true,
        fillColor: enabled ? const Color(0xFFF8F9FA) : Colors.grey.shade200,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 1.5)),
      ),
      // لإظهار الـ (X) بمجرد الكتابة
      onChanged: (_) => setState(() {}),
    );
  }
}