import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorekeeperAuditScreen extends StatefulWidget {
  const StorekeeperAuditScreen({super.key});

  @override
  State<StorekeeperAuditScreen> createState() => _StorekeeperAuditScreenState();
}

class _StorekeeperAuditScreenState extends State<StorekeeperAuditScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('مهام الجرد الموجهة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: primaryNavy,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ابحث عن المنتج المطلوب جرده...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('products').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  var docs = snapshot.data!.docs;
                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((doc) => (doc.data() as Map<String, dynamic>)['name'].toString().toLowerCase().contains(_searchQuery)).toList();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final productId = docs[index].id;
                      final String name = data['name'] ?? 'غير معروف';
                      final String? imageUrl = data['imageUrl']; // تم سحب رابط الصورة بناءً على الفايرستور لديك

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                        elevation: 0,
                        child: ListTile(
                          // عرض صورة المنتج
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                                color: brandOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200)
                            ),
                            child: (imageUrl != null && imageUrl.isNotEmpty)
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Icon(Icons.image_not_supported, color: brandOrange.withOpacity(0.5)),
                              ),
                            )
                                : Icon(Icons.inventory_2_rounded, color: brandOrange),
                          ),
                          title: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('مطلوب جرد هذا الصنف', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            onPressed: () => _showBlindAuditBottomSheet(productId, name, data['stockQuantity'] ?? 0),
                            child: const Text('بدء العد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12)),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
                ),
                const SizedBox(height: 20),
                const Text('تم الإرسال بنجاح! 🎉', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('تم إرسال تقرير الجرد للإدارة بنجاح وفي انتظار الاعتماد.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
        )
    );
  }

  void _showBlindAuditBottomSheet(String productId, String productName, int hiddenSystemStock) {
    TextEditingController goodStockCtrl = TextEditingController();
    TextEditingController damagedStockCtrl = TextEditingController();
    bool hasDamage = false;
    File? damagedPhoto;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setSheetState) {

            Future<void> takePhoto() async {
              final ImagePicker picker = ImagePicker();
              final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
              if (photo != null) {
                setSheetState(() => damagedPhoto = File(photo.path));
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                    left: 20, right: 20, top: 16
                ),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 40),
                          Expanded(
                            child: Text('جرد: $productName', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 16), textAlign: TextAlign.center),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black87, width: 1.5)),
                              child: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('قم بعد القطع الموجودة على الرف الفعلي بعناية', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                      const Divider(height: 24),

                      TextField(
                        controller: goodStockCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'عدد القطع السليمة (الصالحة للبيع)',
                          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 2)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                        child: CheckboxListTile(
                          title: const Text('يوجد قطع تالفة أو مكسورة؟', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red)),
                          activeColor: Colors.red,
                          checkColor: Colors.white,
                          value: hasDamage,
                          onChanged: (val) {
                            setSheetState(() {
                              hasDamage = val ?? false;
                              if (!hasDamage) {
                                damagedStockCtrl.clear();
                                damagedPhoto = null;
                              }
                            });
                          },
                        ),
                      ),

                      if (hasDamage) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: const [
                              Icon(Icons.info_outline, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Expanded(child: Text('اجمع كل القطع التالفة وصورها معاً في صورة واحدة واضحة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: damagedStockCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                                decoration: InputDecoration(
                                  labelText: 'إجمالي الكمية التالفة',
                                  labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.red),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
                                ),
                                onChanged: (val) => setSheetState((){}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: takePhoto,
                              child: Container(
                                width: 80, height: 60,
                                decoration: BoxDecoration(
                                  color: damagedPhoto != null ? Colors.green.shade50 : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: damagedPhoto != null ? Colors.green : Colors.red),
                                ),
                                child: damagedPhoto != null
                                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(damagedPhoto!, fit: BoxFit.cover))
                                    : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt, color: Colors.red, size: 24),
                                    Text('التقط صورة', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      isUploading
                          ? Center(child: CircularProgressIndicator(color: brandOrange))
                          : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () async {
                            String goodQty = goodStockCtrl.text.trim();
                            String damagedQty = damagedStockCtrl.text.trim();

                            if (goodQty.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إدخال عدد القطع السليمة (اكتب صفر لو لا يوجد)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
                              return;
                            }

                            if (hasDamage) {
                              if (damagedQty.isEmpty || damagedQty == '0') {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إدخال إجمالي عدد القطع التالفة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
                                return;
                              }
                              if (damagedPhoto == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إرفاق صورة التوالف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
                                return;
                              }
                            }

                            FocusManager.instance.primaryFocus?.unfocus();
                            setSheetState(() => isUploading = true);

                            try {
                              String? photoUrl;
                              if (hasDamage && damagedPhoto != null) {
                                String fileName = 'audits/${productId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                TaskSnapshot snapshot = await FirebaseStorage.instance.ref().child(fileName).putFile(damagedPhoto!);
                                photoUrl = await snapshot.ref.getDownloadURL();
                              }

                              String currentUser = FirebaseAuth.instance.currentUser?.email ?? 'أمين المخزن';

                              await _firestore.collection('pending_audits').add({
                                'productId': productId,
                                'productName': productName,
                                'systemStock': hiddenSystemStock,
                                'actualGoodStock': int.tryParse(goodQty) ?? 0,
                                'damagedStock': hasDamage ? (int.tryParse(damagedQty) ?? 0) : 0,
                                'photoUrl': photoUrl,
                                'status': 'pending',
                                'submittedBy': currentUser,
                                'timestamp': FieldValue.serverTimestamp(),
                              });

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                _showSuccessDialog(context);
                              }
                            } catch (e) {
                              setSheetState(() => isUploading = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الإرسال: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                            }
                          },
                          child: const Text('إرسال الجرد للاعتماد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
      ),
    );
  }
}