import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/routing/routes.dart';
import '../data/repos/admin_repo.dart';
import 'widgets/google_image_picker_dialog.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final AdminRepo adminRepo = AdminRepo();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  final Color appPrimaryColor = const Color(0xFF0B1E3F);
  final Color appSecondaryColor = const Color(0xFFFF9F0A);

  String currentStatusFilter = 'all';
  String currentCategoryFilter = 'الكل';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 🗑️ دالة مساعدة لحذف قائمة صور دفعة واحدة
  Future<void> _bulkDeleteImages(String docId, List<String> imagesToDelete) async {
    _showLoadingDialog('جاري الحذف...');
    try {
      await _firestore.collection('products').doc(docId).update({
        'imageUrls': FieldValue.arrayRemove(imagesToDelete)
      });
      // تنظيف الرابط القديم إن وجد
      final docSnap = await _firestore.collection('products').doc(docId).get();
      if (docSnap.exists && imagesToDelete.contains(docSnap.data()?['imageUrl'])) {
        await _firestore.collection('products').doc(docId).update({'imageUrl': FieldValue.delete()});
      }
      if (mounted) {
        Navigator.pop(context); // إغلاق التحميل
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      }
    }
  }

  // 🖼 شاشة العرض الكاملة وإدارة الصور (Gallery & Delete)
  void _openFullGalleryAndManage(BuildContext context, String docId, String productName, List<String> currentImages) {
    Set<String> selectedForDeletion = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('معرض صور: $productName', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold))),
                if (selectedForDeletion.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _bulkDeleteImages(docId, selectedForDeletion.toList());
                    },
                  )
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: currentImages.isEmpty
                  ? const Center(child: Text('لا توجد صور لهذا المنتج', style: TextStyle(fontFamily: 'Cairo')))
                  : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: currentImages.length,
                itemBuilder: (context, index) {
                  final img = currentImages[index];
                  final isSelected = selectedForDeletion.contains(img);
                  return GestureDetector(
                    onTap: () {
                      if (selectedForDeletion.isNotEmpty) {
                        setStateSB(() { isSelected ? selectedForDeletion.remove(img) : selectedForDeletion.add(img); });
                      }
                    },
                    onLongPress: () {
                      setStateSB(() { isSelected ? selectedForDeletion.remove(img) : selectedForDeletion.add(img); });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: isSelected ? Colors.red : Colors.grey.shade300, width: isSelected ? 3 : 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(img, fit: BoxFit.cover)),
                          if (isSelected) Container(decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.delete_outline, color: Colors.white, size: 40)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: appSecondaryColor),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showImageUpdateOptions(context, docId, productName);
                },
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('أضف المزيد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🖼️ اختيار صور متعددة من المعرض أو كاميرا
  Future<void> _pickAndUploadImages(ImageSource source, String docId) async {
    List<XFile> pickedFiles = [];
    if (source == ImageSource.gallery) {
      pickedFiles = await _picker.pickMultiImage(imageQuality: 80);
    } else {
      final XFile? singleFile = await _picker.pickImage(source: source, imageQuality: 80);
      if (singleFile != null) pickedFiles.add(singleFile);
    }

    if (pickedFiles.isEmpty || !mounted) return;
    _showLoadingDialog('جاري رفع الصور...');

    try {
      List<String> uploadedUrls = [];
      for (var pickedFile in pickedFiles) {
        String fileName = 'products_images/${docId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        TaskSnapshot snapshot = await FirebaseStorage.instance.ref().child(fileName).putFile(File(pickedFile.path));
        uploadedUrls.add(await snapshot.ref.getDownloadURL());
      }
      await _firestore.collection('products').doc(docId).update({'imageUrls': FieldValue.arrayUnion(uploadedUrls)});
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الإضافة!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green)); }
    } catch (e) {
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الرفع: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red)); }
    }
  }

  // 🌐 جلب من جوجل
  Future<void> _pickFromGoogleSearch(String docId, String productName) async {
    final List<String>? selectedImageUrls = await showDialog<List<String>>(context: context, barrierDismissible: false, builder: (context) => GoogleImagePickerDialog(productName: productName));
    if (selectedImageUrls != null && selectedImageUrls.isNotEmpty && mounted) {
      _showLoadingDialog('جاري الربط...');
      try {
        await _firestore.collection('products').doc(docId).update({'imageUrls': FieldValue.arrayUnion(selectedImageUrls)});
        if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة صور جوجل!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green)); }
      } catch (e) {
        if (mounted) Navigator.pop(context);
      }
    }
  }

  void _showLoadingDialog(String msg) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: appSecondaryColor), const SizedBox(height: 16), Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))])));
  }

  // القائمة السفلية للصور
  void _showImageUpdateOptions(BuildContext context, String docId, String productName) {
    showModalBottomSheet(
      context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إضافة صور لـ:\n$productName', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: appPrimaryColor)),
            const Divider(thickness: 2, height: 30),
            ListTile(leading: Icon(Icons.travel_explore, color: appSecondaryColor, size: 30), title: const Text('بحث من جوجل 🌐', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(ctx); _pickFromGoogleSearch(docId, productName); }),
            ListTile(leading: const Icon(Icons.photo_library, color: Colors.blue, size: 30), title: const Text('اختيار من المعرض 🖼️', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(ctx); _pickAndUploadImages(ImageSource.gallery, docId); }),
            ListTile(leading: const Icon(Icons.camera_alt, color: Colors.teal, size: 30), title: const Text('التقاط كاميرا 📸', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(ctx); _pickAndUploadImages(ImageSource.camera, docId); }),
          ],
        ),
      ),
    );
  }

  // ✏️ الانتقال لشاشة التعديل وإرسال البيانات
  void _navigateToEditProduct(BuildContext context, String docId, Map<String, dynamic> productData) {
    // نرسل الـ ID والداتا لـ Routing لتقوم شاشة AddProduct بفرشها لاحقاً
    Map<String, dynamic> extraData = {'id': docId, ...productData};
    context.push(Routes.addProduct, extra: extraData);
  }

  // ➕ نافذة إضافة دفعة جديدة (تصميم انسيابي حديث بدون Dropdowns)
  // ➕ نافذة إضافة دفعة جديدة (تصميم انسيابي حديث بدون Dropdowns)
  void _showAddBatchModal(BuildContext context, String docId, String productName) {
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController costPriceController = TextEditingController();
    final TextEditingController supplierController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        // 👈 هذا هو السطر السحري الذي يمنع خطأ الكيبورد (SingleChildScrollView)
        child: SingleChildScrollView(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // مؤشر السحب (Drag Handle)
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),

                Text('إضافة دفعة: $productName', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: appPrimaryColor)),
                const SizedBox(height: 24),

                // حقل الكمية
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'الكمية المضافة',
                    labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixIcon: const Icon(Icons.add_shopping_cart, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // حقل السعر
                TextField(
                  controller: costPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'سعر الشراء (للقطعة)',
                    labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixIcon: const Icon(Icons.attach_money, color: Colors.orange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // حقل المورد (إدخال نصي حر لتجنب القوائم المنسدلة المزعجة)
                TextField(
                  controller: supplierController,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'اسم المورد (اختياري)',
                    labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixIcon: const Icon(Icons.local_shipping_outlined, color: Colors.blueAccent),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),

                // زر الحفظ الأنيق
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final int? addedQty = int.tryParse(quantityController.text.trim());
                    final double? costPrice = double.tryParse(costPriceController.text.trim());
                    final String supplierName = supplierController.text.trim();

                    if (addedQty != null && addedQty > 0 && costPrice != null && costPrice >= 0) {
                      Navigator.pop(ctx);
                      _showLoadingDialog('جاري تسجيل الدفعة...');

                      try {
                        final newBatch = {
                          'batchId': 'batch_manual_${DateTime.now().millisecondsSinceEpoch}',
                          'costPrice': costPrice,
                          'quantity': addedQty,
                          'supplier': supplierName.isNotEmpty ? supplierName : 'غير محدد',
                          'dateAdded': Timestamp.now(),
                        };

                        await _firestore.collection('products').doc(docId).update({
                          'stockQuantity': FieldValue.increment(addedQty),
                          'batches': FieldValue.arrayUnion([newBatch])
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تسجيل الدفعة بنجاح!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.teal)
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red)
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى إدخال الكمية والسعر بشكل صحيح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.redAccent)
                      );
                    }
                  },
                  child: const Text('حفظ الدفعة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(title: const Text('إدارة المنتجات والتسعير', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)), backgroundColor: appPrimaryColor, foregroundColor: Colors.white, centerTitle: true, elevation: 0),
        body: Column(
          children: [
            // 🔍 البحث
            Container(
              color: appPrimaryColor, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(controller: _searchController, onChanged: (val) => setState(() => searchQuery = val.toLowerCase()), style: const TextStyle(fontFamily: 'Cairo'), decoration: InputDecoration(hintText: 'ابحث باسم المنتج سريعاً...', hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14), prefixIcon: const Icon(Icons.search, color: Colors.grey), suffixIcon: searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); setState(() => searchQuery = ''); }) : null, filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            ),

            // 🎛️ فلاتر
            Container(
              color: Colors.white, width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [_buildStatusChip('الكل', 'all', Icons.all_inclusive), const SizedBox(width: 8), _buildStatusChip('متاح بالمخزن', 'active', Icons.check_circle_outline), const SizedBox(width: 8), _buildStatusChip('مسودات (مخفي)', 'archived', Icons.archive_outlined)])),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('categories').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox(height: 35);
                      final categories = ['الكل', ...snapshot.data!.docs.map((e) => e.id)];
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: categories.map((cat) {
                          final isSelected = currentCategoryFilter == cat;
                          return Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Text(cat, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)), selected: isSelected, onSelected: (_) => setState(() => currentCategoryFilter = cat), selectedColor: appSecondaryColor.withValues(alpha: 0.2), backgroundColor: Colors.grey.shade100, labelStyle: TextStyle(color: isSelected ? appSecondaryColor : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), side: BorderSide(color: isSelected ? appSecondaryColor : Colors.transparent)));
                        }).toList()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // 📋 المنتجات
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('products').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: appSecondaryColor));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                  var filteredDocs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final String name = (data['name'] ?? '').toString().toLowerCase();
                    final String category = (data['category'] ?? '').toString();
                    final bool isActive = data['isActive'] ?? true;
                    if (searchQuery.isNotEmpty && !name.contains(searchQuery)) return false;
                    if (currentCategoryFilter != 'الكل' && category != currentCategoryFilter) return false;
                    if (currentStatusFilter == 'active' && !isActive) return false;
                    if (currentStatusFilter == 'archived' && isActive) return false;
                    return true;
                  }).toList();

                  if (filteredDocs.isEmpty) return _buildEmptyState();

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 12, right: 12, left: 12, bottom: 90),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final bool isActive = data['isActive'] ?? true;
                      final String name = data['name'] ?? 'بدون اسم';
                      final String category = data['category'] ?? 'عام';
                      final price = data['price'] ?? 0.0;
                      final int stock = data['stockQuantity'] ?? 0;

                      List<String> productImages = [];
                      if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) productImages.add(data['imageUrl'].toString());
                      if (data['imageUrls'] != null) {
                        for (var img in List<String>.from(data['imageUrls'])) { if (!productImages.contains(img)) productImages.add(img); }
                      }

                      return Card(
                        color: isActive ? Colors.white : const Color(0xFFFFFDF5), margin: const EdgeInsets.only(bottom: 12), elevation: isActive ? 1 : 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isActive ? Colors.grey.shade200 : Colors.orange.withValues(alpha: 0.3))),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _openFullGalleryAndManage(context, doc.id, name, productImages),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      width: 80, height: 80,
                                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: productImages.isNotEmpty
                                            ? Image.network(productImages.first, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                                            : const Center(child: Icon(Icons.add_a_photo, color: Colors.grey, size: 30)),
                                      ),
                                    ),
                                    if (productImages.length > 1)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.black87, borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
                                        child: Text('+${productImages.length - 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo', color: isActive ? Colors.black87 : Colors.grey.shade700, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(category, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'Cairo')),
                                    const SizedBox(height: 6),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          Text('$price ج.م', style: TextStyle(color: appSecondaryColor, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                                          const SizedBox(width: 12),
                                          Text('رصيد: $stock', style: TextStyle(color: stock > 0 ? Colors.green.shade700 : Colors.red, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Cairo')),
                                          const SizedBox(width: 8),

                                          _buildCompactActionBtn(Icons.add_box, Colors.teal, 'إضافة دفعة', isActive ? () => _showAddBatchModal(context, doc.id, name) : null),
                                          const SizedBox(width: 4),
                                          _buildCompactActionBtn(Icons.edit, Colors.blue, 'تعديل', isActive ? () => _navigateToEditProduct(context, doc.id, data) : null),
                                          const SizedBox(width: 4),
                                          _buildCompactActionBtn(isActive ? Icons.visibility_off : Icons.visibility, isActive ? Colors.red : Colors.green, isActive ? 'إخفاء' : 'نشر', () { _firestore.collection('products').doc(doc.id).update({'isActive': !isActive}); }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push(Routes.addProduct), backgroundColor: appPrimaryColor, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('إضافة منتج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildStatusChip(String label, String filterValue, IconData icon) {
    final isSelected = currentStatusFilter == filterValue;
    return ChoiceChip(label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.black87), const SizedBox(width: 4), Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12))]), selected: isSelected, onSelected: (_) => setState(() => currentStatusFilter = filterValue), selectedColor: appPrimaryColor, backgroundColor: Colors.grey.shade200, labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), showCheckmark: false);
  }

  Widget _buildCompactActionBtn(IconData icon, Color color, String tooltip, VoidCallback? onTap) {
    return Tooltip(message: tooltip, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: onTap == null ? Colors.grey.shade200 : color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: onTap == null ? Colors.transparent : color.withValues(alpha: 0.3))), child: Icon(icon, size: 16, color: onTap == null ? Colors.grey : color))));
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade400), const SizedBox(height: 16), const Text('لا توجد منتجات مطابقة', style: TextStyle(fontSize: 15, color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold))]));
}