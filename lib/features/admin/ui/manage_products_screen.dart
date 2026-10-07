import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/routing/routes.dart';
import '../data/repos/admin_repo.dart';
import 'widgets/google_image_picker_dialog.dart';
import 'package:flutter/services.dart';
class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final AdminRepo adminRepo = AdminRepo();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  final Color appPrimaryColor = const Color(0xFF0B1E3F); // كحلي
  final Color appSecondaryColor = const Color(0xFFFF9F0A); // برتقالي

  String currentStatusFilter = 'all';
  String currentCategoryFilter = 'الكل';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 🗑️ دالة مساعدة لحذف قائمة صور
  Future<void> _bulkDeleteImages(String docId, List<String> imagesToDelete) async {
    _showLoadingDialog('جاري الحذف...');
    try {
      await _firestore.collection('products').doc(docId).update({
        'imageUrls': FieldValue.arrayRemove(imagesToDelete)
      });
      final docSnap = await _firestore.collection('products').doc(docId).get();
      if (docSnap.exists && imagesToDelete.contains(docSnap.data()?['imageUrl'])) {
        await _firestore.collection('products').doc(docId).update({'imageUrl': FieldValue.delete()});
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      }
    }
  }

  // 🖼 شاشة العرض الكاملة وإدارة الصور
  void _openFullGalleryAndManage(BuildContext context, String docId, String productName, List<String> currentImages) {
    Set<String> selectedForDeletion = {};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('معرض صور:\n$productName', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold))),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(img, fit: BoxFit.cover)),
                          if (isSelected) Container(decoration: BoxDecoration(color: Colors.red.withOpacity(0.4), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_outline, color: Colors.white, size: 40)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: appSecondaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showImageUpdateOptions(context, docId, productName);
                },
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('أضف المزيد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

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
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الإضافة بنجاح!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.green)); }
    } catch (e) {
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الرفع: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red)); }
    }
  }

  Future<void> _pickFromGoogleSearch(String docId, String productName) async {
    final List<String>? selectedImageUrls = await showDialog<List<String>>(context: context, barrierDismissible: false, builder: (context) => GoogleImagePickerDialog(productName: productName));
    if (selectedImageUrls != null && selectedImageUrls.isNotEmpty && mounted) {
      _showLoadingDialog('جاري الربط...');
      try {
        await _firestore.collection('products').doc(docId).update({'imageUrls': FieldValue.arrayUnion(selectedImageUrls)});
        if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة صور جوجل بنجاح!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.green)); }
      } catch (e) {
        if (mounted) Navigator.pop(context);
      }
    }
  }

  void _showLoadingDialog(String msg) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), content: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: appSecondaryColor), const SizedBox(height: 16), Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))])));
  }

  void _showImageUpdateOptions(BuildContext context, String docId, String productName) {
    showModalBottomSheet(
      context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text('إضافة صور لـ:\n$productName', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: appPrimaryColor)),
            const Divider(thickness: 1, height: 30),
            ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: appSecondaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.travel_explore, color: appSecondaryColor, size: 24)), title: const Text('بحث من جوجل 🌐', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(ctx); _pickFromGoogleSearch(docId, productName); }),
            ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.photo_library, color: Colors.blue, size: 24)), title: const Text('اختيار من المعرض 🖼️', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(ctx); _pickAndUploadImages(ImageSource.gallery, docId); }),
            ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.teal, size: 24)), title: const Text('التقاط كاميرا 📸', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(ctx); _pickAndUploadImages(ImageSource.camera, docId); }),
          ],
        ),
      ),
    );
  }

  void _navigateToEditProduct(BuildContext context, String docId, Map<String, dynamic> productData) {
    Map<String, dynamic> extraData = {'id': docId, ...productData};
    context.push(Routes.addProduct, extra: extraData);
  }

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
        child: SingleChildScrollView(
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                Text('إضافة دفعة: $productName', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: appPrimaryColor)),
                const SizedBox(height: 24),
                TextField(
                  controller: quantityController, keyboardType: TextInputType.number, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  decoration: InputDecoration(labelText: 'الكمية المضافة', labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey), filled: true, fillColor: Colors.grey.shade50, prefixIcon: const Icon(Icons.add_shopping_cart, color: Colors.teal), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costPriceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  decoration: InputDecoration(labelText: 'سعر الشراء (للقطعة)', labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey), filled: true, fillColor: Colors.grey.shade50, prefixIcon: const Icon(Icons.attach_money, color: Colors.orange), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: supplierController, keyboardType: TextInputType.text, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  decoration: InputDecoration(labelText: 'اسم المورد (اختياري)', labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey), filled: true, fillColor: Colors.grey.shade50, prefixIcon: const Icon(Icons.local_shipping_outlined, color: Colors.blueAccent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  onPressed: () async {
                    final int? addedQty = int.tryParse(quantityController.text.trim());
                    final double? costPrice = double.tryParse(costPriceController.text.trim());
                    final String supplierName = supplierController.text.trim();
                    if (addedQty != null && addedQty > 0 && costPrice != null && costPrice >= 0) {
                      Navigator.pop(ctx);
                      _showLoadingDialog('جاري تسجيل الدفعة...');
                      try {
                        final newBatch = {'batchId': 'batch_manual_${DateTime.now().millisecondsSinceEpoch}', 'costPrice': costPrice, 'quantity': addedQty, 'supplier': supplierName.isNotEmpty ? supplierName : 'غير محدد', 'dateAdded': Timestamp.now()};
                        await _firestore.collection('products').doc(docId).update({'stockQuantity': FieldValue.increment(addedQty), 'batches': FieldValue.arrayUnion([newBatch])});
                        if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الدفعة بنجاح!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.teal)); }
                      } catch (e) {
                        if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red)); }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال الكمية والسعر بشكل صحيح', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent));
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

  // 🚀 دالة لرسم التبويبات (Tabs) بشكل عصري ومريح بدل الـ ChoiceChips القديمة
  Widget _buildModernFilterTab(String label, String value, bool isStatus) {
    bool isSelected = isStatus ? currentStatusFilter == value : currentCategoryFilter == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isStatus) currentStatusFilter = value;
          else currentCategoryFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (isStatus ? appPrimaryColor : appSecondaryColor.withOpacity(0.15)) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? (isStatus ? appPrimaryColor : appSecondaryColor) : Colors.grey.shade300, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? (isStatus ? Colors.white : appSecondaryColor) : Colors.grey.shade600,
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
        appBar: AppBar(title: const Text('إدارة المنتجات', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)), backgroundColor: appPrimaryColor, foregroundColor: Colors.white, centerTitle: true, elevation: 0),
        body: Column(
          children: [
            // 🚀 شريط البحث الجديد (Floating Search Bar)
            Container(
              color: appPrimaryColor,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن منتج...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: appSecondaryColor),
                      suffixIcon: searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, color: Colors.grey), onPressed: () { _searchController.clear(); setState(() => searchQuery = ''); }) : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: InputBorder.none,
                    )
                ),
              ),
            ),

            // 🎛️ التبويبات العصرية (Modern Tabs)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. تبويبات الحالة
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                          children: [
                            _buildModernFilterTab('الكل', 'all', true),
                            _buildModernFilterTab('متاح', 'active', true),
                            _buildModernFilterTab('مخفي', 'archived', true),
                          ]
                      )
                  ),
                  const SizedBox(height: 12),

                  // 2. تبويبات الأقسام
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('categories').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox(height: 35);
                      final categories = ['الكل', ...snapshot.data!.docs.map((e) => e.id)];
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                            children: categories.map((cat) => _buildModernFilterTab(cat, cat, false)).toList()
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // 📋 قائمة المنتجات
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
                    padding: const EdgeInsets.only(top: 16, right: 16, left: 16, bottom: 90),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final bool isActive = data['isActive'] ?? true;
                      final String name = data['name'] ?? 'بدون اسم';
                      final String category = data['category'] ?? 'عام';
                      final price = data['price'] ?? 0.0;
                      final int stock = data['stockQuantity'] ?? 0;

                      // 🚀 جلب الحد الأدنى للمخزون المحفوظ في الفايربيز (أو افتراضي 5 لو مفيش)
                      final int lowStockThreshold = data['lowStockThreshold'] ?? 5;
                      final bool isLowStock = stock <= lowStockThreshold; // هل المخزون خطر؟

                      List<String> productImages = [];
                      if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) productImages.add(data['imageUrl'].toString());
                      if (data['imageUrls'] != null) {
                        for (var img in List<String>.from(data['imageUrls'])) { if (!productImages.contains(img)) productImages.add(img); }
                      }

                      return Card(
                        color: isActive ? Colors.white : const Color(0xFFFAFAFA),
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: isActive ? 2 : 0,
                        shadowColor: Colors.black.withOpacity(0.08),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: isActive ? Colors.transparent : Colors.grey.shade300)
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => _openFullGalleryAndManage(context, doc.id, name, productImages),
                                    child: Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Container(
                                          width: 90, height: 90,
                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: productImages.isNotEmpty
                                                ? Image.network(productImages.first, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey.shade400))
                                                : Icon(Icons.add_a_photo, color: Colors.grey.shade300, size: 40),
                                          ),
                                        ),
                                        if (productImages.length > 1)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: const BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.only(topLeft: Radius.circular(10), bottomRight: Radius.circular(10))),
                                            child: Text('+${productImages.length - 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo', color: isActive ? appPrimaryColor : Colors.grey.shade600, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                                            ),
                                            Tooltip(
                                              message: isActive ? 'المنتج متاح' : 'المنتج مخفي',
                                              child: SizedBox(
                                                height: 24,
                                                child: Switch(
                                                  value: isActive,
                                                  activeColor: Colors.green,
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  onChanged: (val) {
                                                    _firestore.collection('products').doc(doc.id).update({'isActive': val});
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(category, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 12),

                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(color: appSecondaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                              child: Text('$price ج.م', style: TextStyle(color: appSecondaryColor, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                                            ),
                                            // 🚀 مؤشر المخزون الذكي (بينور أحمر وبيطلع تنبيه لو قل عن العدد اللي في الفايربيز)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                  color: isLowStock ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: isLowStock ? Colors.red.withOpacity(0.5) : Colors.transparent)
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isLowStock) ...[
                                                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  Text(
                                                      'المخزون: $stock',
                                                      style: TextStyle(color: isLowStock ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),

                              // 🚀 تعديل الترتيب: (إضافة كمية يمين) و (تعديل شمال)
                              Row(
                                children: [
                                  // زرار إضافة كمية (على اليمين)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal.withOpacity(0.1),
                                        foregroundColor: Colors.teal.shade700,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: isActive ? () => _showAddBatchModal(context, doc.id, name) : null,
                                      icon: const Icon(Icons.add_box_rounded, size: 18),
                                      label: const Text('إضافة كمية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // زرار تعديل البيانات (على الشمال)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: appPrimaryColor.withOpacity(0.08),
                                        foregroundColor: appPrimaryColor,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: isActive ? () => _navigateToEditProduct(context, doc.id, data) : null,
                                      icon: const Icon(Icons.edit_rounded, size: 18),
                                      label: const Text('تعديل البيانات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                ],
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
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push(Routes.addProduct),
            backgroundColor: appPrimaryColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة منتج جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15))
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300), const SizedBox(height: 16), const Text('لا توجد منتجات مطابقة للبحث', style: TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold))]));
}