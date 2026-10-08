import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../purchases/services/purchase_service.dart';

// 🚀 مسار نافذة بحث صور جوجل
import '../../admin/ui/widgets/google_image_picker_dialog.dart';

class ManualPurchaseScreen extends StatefulWidget {
  const ManualPurchaseScreen({super.key});

  @override
  State<ManualPurchaseScreen> createState() => _ManualPurchaseScreenState();
}

class _ManualPurchaseScreenState extends State<ManualPurchaseScreen> {
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _invoiceNumberController = TextEditingController();
  late TextEditingController _dateController;
  late DateTime _selectedDate;

  final List<Map<String, dynamic>> _invoiceItems = [];
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;
  final Color bgSoftColor = const Color(0xFFF4F7FB);

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateController = TextEditingController(
      text: "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
    );
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceNumberController.dispose();
    _dateController.dispose();
    for (var item in _invoiceItems) {
      item['qtyController']?.dispose();
      item['conversionFactorController']?.dispose();
      item['priceController']?.dispose();
      item['sellingPriceController']?.dispose();
    }
    super.dispose();
  }

  double get _totalAmount {
    return _invoiceItems.fold(0.0, (sum, item) {
      double price = double.tryParse(item['priceController'].text) ?? 0.0;
      int qty = int.tryParse(item['qtyController'].text) ?? 0;
      return sum + (price * qty);
    });
  }

  void _updateTotal() {
    setState(() {});
  }

  // 🚀 السحر هنا: دالة الإشعارات (Snackbars) الجديدة اللي شكلها محترم ومختصر
  void _showCustomSnackBar(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // يخفي أي إشعار قديم الأول
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: Icon(isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : Colors.red.shade600, // أخضر فخم أو أحمر
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 20, right: 20, left: 20),
        elevation: 0,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLoadingDialog(String msg) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: brandOrange),
                  const SizedBox(height: 16),
                  Text(msg, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy))
                ]
            )
        )
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryNavy, onPrimary: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _showAddCategorySheet(bool isSubCategory, String? parentCategory, Function(String) onAdded) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isSubCategory ? 'إضافة قسم فرعي جديد' : 'إضافة قسم أساسي جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                      IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'اكتب اسم القسم هنا...',
                      hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: bgSoftColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final val = ctrl.text.trim();
                        if (val.isNotEmpty) {
                          Navigator.pop(ctx);
                          _showLoadingDialog('جاري الإضافة...');
                          try {
                            if (isSubCategory && parentCategory != null) {
                              await FirebaseFirestore.instance.collection('categories').doc(parentCategory).set({
                                'subCategories': FieldValue.arrayUnion([val])
                              }, SetOptions(merge: true));
                            } else {
                              await FirebaseFirestore.instance.collection('categories').doc(val).set({
                                'subCategories': ['الكل']
                              }, SetOptions(merge: true));
                            }
                            if (mounted) {
                              Navigator.pop(context);
                              onAdded(val);
                            }
                          } catch(e) {
                            if (mounted) {
                              Navigator.pop(context);
                              _showCustomSnackBar('فشل إضافة القسم', false); // إشعار شيك
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: brandOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: const Text('إضافة وحفظ', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCategorySheet(String title, List<String> items, String? selectedItem, bool isSubCategory, String? parentCategory, Function(String) onSelect) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 28), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = item == selectedItem;
                    return ListTile(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelect(item);
                        Navigator.pop(ctx);
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: isSelected ? brandOrange.withOpacity(0.1) : Colors.transparent,
                      title: Text(item, style: TextStyle(fontFamily: 'Cairo', fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? brandOrange : Colors.black87)),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: brandOrange) : null,
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              ListTile(
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddCategorySheet(isSubCategory, parentCategory, onSelect);
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: brandOrange.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.add_rounded, color: brandOrange, size: 22),
                ),
                title: Text('إضافة قسم جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: brandOrange, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMultiSelectProductsDialog() {
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          List<Map<String, dynamic>> tempSelectedProducts = [];

          return StatefulBuilder(
              builder: (context, setSheetState) {
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.85,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 40),
                            Text('تحديد الأصناف للفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                            IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 28), onPressed: () => Navigator.pop(context)),
                          ],
                        ),
                        const Divider(height: 10),

                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('products').snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                var products = snapshot.data!.docs;

                                if (products.isEmpty) {
                                  return const Center(child: Text('لا توجد منتجات مسجلة.', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)));
                                }

                                return ListView.builder(
                                  itemCount: products.length,
                                  itemBuilder: (context, index) {
                                    final doc = products[index];
                                    final data = doc.data() as Map<String, dynamic>;

                                    bool isAlreadyInInvoice = _invoiceItems.any((item) => item['mappedId'] == doc.id);
                                    bool isSelectedHere = tempSelectedProducts.any((item) => item['mappedId'] == doc.id);
                                    bool isChecked = isAlreadyInInvoice || isSelectedHere;

                                    return CheckboxListTile(
                                      activeColor: brandOrange,
                                      checkColor: Colors.white,
                                      title: Text(data['name'] ?? '', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isAlreadyInInvoice ? Colors.grey : Colors.black)),
                                      subtitle: Text('السعر الحالي: ${data['costPrice'] ?? 0} ج.م', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600)),
                                      value: isChecked,
                                      onChanged: isAlreadyInInvoice ? null : (bool? value) {
                                        setSheetState(() {
                                          if (value == true) {
                                            tempSelectedProducts.add({
                                              'mappedId': doc.id,
                                              'mappedName': data['name'],
                                              'category': data['category'] ?? 'الكل',
                                              'subCategory': data['subCategory'] ?? 'الكل',
                                              'lastCostPrice': data['costPrice'] ?? 0.0,
                                              'lastSellingPrice': data['price'] ?? 0.0,
                                              'imageUrls': data['imageUrls'] != null ? List<String>.from(data['imageUrls']) : (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty ? [data['imageUrl']] : <String>[]),
                                            });
                                          } else {
                                            tempSelectedProducts.removeWhere((item) => item['mappedId'] == doc.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                );
                              }
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: () {
                                setState(() {
                                  for (var prod in tempSelectedProducts) {
                                    _invoiceItems.insert(0, {
                                      'mappedName': prod['mappedName'],
                                      'rawAiName': prod['mappedName'],
                                      'mappedId': prod['mappedId'],
                                      'isNewProduct': false,
                                      'mainCategory': prod['category'],
                                      'subCategory': prod['subCategory'],
                                      'imageUrls': prod['imageUrls'],
                                      'conversionFactorController': TextEditingController(text: '1')..addListener(_updateTotal),
                                      'qtyController': TextEditingController(text: '1')..addListener(_updateTotal),
                                      'priceController': TextEditingController(text: prod['lastCostPrice'].toString())..addListener(_updateTotal),
                                      'sellingPriceController': TextEditingController(text: prod['lastSellingPrice'].toString()),
                                    });
                                  }
                                });
                                Navigator.pop(context);
                              },
                              child: Text('إضافة (${tempSelectedProducts.length}) منتج للفاتورة', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  void _openAddNewProductDialog() {
    FocusManager.instance.primaryFocus?.unfocus();
    final nameController = TextEditingController();
    String selectedCategory = 'الكل';
    String selectedSubCategory = 'الكل';
    List<String> currentSubCategories = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        Text('تأسيس صنف جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                        IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 28), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      decoration: InputDecoration(labelText: 'اسم المنتج الجديد', filled: true, fillColor: bgSoftColor, prefixIcon: Icon(Icons.edit_note, color: brandOrange), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    ),
                    const SizedBox(height: 16),

                    StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          final docs = snapshot.data!.docs;
                          List<String> mainCategories = docs.map((doc) => doc.id).toList();

                          var docItem = docs.where((d) => d.id == selectedCategory).firstOrNull;
                          if (docItem != null) {
                            final docData = docItem.data() as Map<String, dynamic>;
                            currentSubCategories = List<String>.from(docData['subCategories'] ?? []);
                          } else {
                            currentSubCategories = [];
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('تصنيف المنتج:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: primaryNavy)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () {
                                  _showCategorySheet('القسم الأساسي', mainCategories, selectedCategory, false, null, (val) {
                                    setSheetState(() {
                                      selectedCategory = val;
                                      selectedSubCategory = 'الكل';
                                    });
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(color: bgSoftColor, borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(selectedCategory, style: TextStyle(fontFamily: 'Cairo', color: primaryNavy, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                      Icon(Icons.keyboard_arrow_down, color: primaryNavy),
                                    ],
                                  ),
                                ),
                              ),
                              if (currentSubCategories.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () {
                                    _showCategorySheet('القسم الفرعي', currentSubCategories, selectedSubCategory, true, selectedCategory, (val) {
                                      setSheetState(() => selectedSubCategory = val);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(color: bgSoftColor, borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(selectedSubCategory, style: TextStyle(fontFamily: 'Cairo', color: primaryNavy, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                        Icon(Icons.keyboard_arrow_down, color: primaryNavy),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        }
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: brandOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          if (nameController.text.trim().isEmpty) return;
                          setState(() {
                            _invoiceItems.insert(0, {
                              'mappedName': nameController.text.trim(),
                              'rawAiName': nameController.text.trim(),
                              'mappedId': null,
                              'isNewProduct': true,
                              'mainCategory': selectedCategory,
                              'subCategory': selectedSubCategory,
                              'imageUrls': <String>[],
                              'conversionFactorController': TextEditingController(text: '1')..addListener(_updateTotal),
                              'qtyController': TextEditingController(text: '1')..addListener(_updateTotal),
                              'priceController': TextEditingController(text: '0')..addListener(_updateTotal),
                              'sellingPriceController': TextEditingController(text: '0'),
                            });
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('إدراج للفاتورة لتسعيره', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showImageOptionsBottomSheet(int index, String productName) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Text('إضافة صورة لـ: $productName', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy)),
              const Divider(thickness: 1, height: 30),
              ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: brandOrange.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.travel_explore, color: brandOrange, size: 24)),
                  title: const Text('بحث من جوجل 🌐', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Future.delayed(const Duration(milliseconds: 150), () {
                      _pickFromGoogleSearch(index, productName);
                    });
                  }
              ),
              ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.photo_library, color: Colors.blue, size: 24)),
                  title: const Text('اختيار من المعرض 🖼️', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  onTap: () { Navigator.pop(ctx); _pickAndUploadImage(ImageSource.gallery, index); }
              ),
              ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.teal, size: 24)),
                  title: const Text('التقاط كاميرا 📸', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  onTap: () { Navigator.pop(ctx); _pickAndUploadImage(ImageSource.camera, index); }
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromGoogleSearch(int index, String productName) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final List<String>? selectedImageUrls = await showDialog<List<String>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => GoogleImagePickerDialog(productName: productName)
    );

    FocusManager.instance.primaryFocus?.unfocus();

    if (selectedImageUrls != null && selectedImageUrls.isNotEmpty && mounted) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _invoiceItems[index]['imageUrls'] = selectedImageUrls;
          });
          FocusManager.instance.primaryFocus?.unfocus();
          _showCustomSnackBar('تم ربط الصورة بنجاح', true); // 👈 إشعار الفخامة
        }
      });
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source, int index) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
    if (image == null || !mounted) return;

    _showLoadingDialog('جاري رفع الصورة...');
    try {
      String fileName = 'products_images/manual_inv_${DateTime.now().millisecondsSinceEpoch}.jpg';
      TaskSnapshot snapshot = await FirebaseStorage.instance.ref().child(fileName).putFile(File(image.path));
      String downloadUrl = await snapshot.ref.getDownloadURL();

      if (mounted) {
        setState(() {
          List<String> currentUrls = List<String>.from(_invoiceItems[index]['imageUrls'] ?? []);
          currentUrls.add(downloadUrl);
          _invoiceItems[index]['imageUrls'] = currentUrls;
        });
        Navigator.pop(context);
        _showCustomSnackBar('تم رفع الصورة بنجاح', true); // 👈 إشعار الفخامة
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showCustomSnackBar('فشل الرفع: تأكد من الصلاحيات والإنترنت', false); // 👈 إشعار الخطأ الشيك
      }
    }
  }

  Future<void> _saveInvoice() async {
    if (_supplierController.text.trim().isEmpty) {
      _showCustomSnackBar('يجب إدخال اسم المورد', false);
      return;
    }
    if (_invoiceNumberController.text.trim().isEmpty) {
      _showCustomSnackBar('يجب إدخال رقم الفاتورة', false);
      return;
    }
    if (_invoiceItems.isEmpty) {
      _showCustomSnackBar('الفاتورة فارغة، أضف أصنافاً', false);
      return;
    }

    for (var item in _invoiceItems) {
      double price = double.tryParse(item['priceController'].text) ?? 0.0;
      int qty = int.tryParse(item['qtyController'].text) ?? 0;
      int conversion = int.tryParse(item['conversionFactorController'].text) ?? 1;

      if (price <= 0 || qty <= 0 || conversion <= 0) {
        _showCustomSnackBar('تأكد من صحة كميات وأسعار ${item['mappedName']}', false);
        return;
      }
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);

    try {
      List<Map<String, dynamic>> finalItemsToSave = _invoiceItems.map((item) {
        return {
          'mappedName': item['mappedName'],
          'rawAiName': item['rawAiName'],
          'mappedId': item['mappedId'],
          'isNewProduct': item['isNewProduct'],
          'mainCategory': item['mainCategory'],
          'subCategory': item['subCategory'],
          'conversionFactor': int.parse(item['conversionFactorController'].text),
          'imageUrls': item['imageUrls'],
          'qty': int.parse(item['qtyController'].text),
          'price': double.parse(item['priceController'].text),
          'sellingPrice': double.parse(item['sellingPriceController'].text),
        };
      }).toList();

      final purchaseService = PurchaseService();
      await purchaseService.processApprovedInvoice(
        supplierName: _supplierController.text.trim(),
        invoiceNumber: _invoiceNumberController.text.trim(),
        invoiceDate: _selectedDate,
        items: finalItemsToSave,
      );

      if (mounted) {
        _showCustomSnackBar('تم ترحيل الفاتورة وتحديث المخزون', true);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) context.pop();
        });
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar('حدث خطأ أثناء الترحيل', false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildCenteredInput({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    Color? labelColor,
    Color? fillColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: labelColor ?? primaryNavy,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 16, color: Colors.black87),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: fillColor ?? bgSoftColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: bgSoftColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('إدخال فاتورة (يدوي)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            centerTitle: true,
            backgroundColor: primaryNavy,
            elevation: 0,
            actions: [
              if (Navigator.canPop(context))
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              if (Navigator.canPop(context)) const SizedBox(width: 8),
            ],
          ),
          body: _isSaving
              ? Center(child: CircularProgressIndicator(color: brandOrange))
              : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بيانات الفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 16),
                      TextFormField(controller: _supplierController, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14), decoration: InputDecoration(labelText: 'اسم المورد / الشركة', labelStyle: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'), prefixIcon: Icon(Icons.store_rounded, color: primaryNavy), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: bgSoftColor)),
                      const SizedBox(height: 12),
                      TextFormField(controller: _invoiceNumberController, keyboardType: TextInputType.text, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14), decoration: InputDecoration(labelText: 'رقم الفاتورة (مطلوب)', labelStyle: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'), prefixIcon: const Icon(Icons.numbers_rounded, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: bgSoftColor)),
                      const SizedBox(height: 12),
                      TextFormField(controller: _dateController, readOnly: true, onTap: () => _selectDate(context), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14), decoration: InputDecoration(labelText: 'التاريخ', labelStyle: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'), prefixIcon: Icon(Icons.calendar_month_rounded, color: brandOrange), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: bgSoftColor)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _openMultiSelectProductsDialog,
                        icon: const Icon(Icons.checklist_rtl_rounded, size: 20),
                        label: const Text('تحديد الأصناف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(backgroundColor: brandOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        onPressed: _openAddNewProductDialog,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(backgroundColor: primaryNavy.withOpacity(0.1), foregroundColor: primaryNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _invoiceItems.isEmpty
                    ? Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.post_add_rounded, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('حدد الأصناف وابدأ التسعير..', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _invoiceItems.length,
                  itemBuilder: (context, index) {
                    final item = _invoiceItems[index];
                    List<String> productUrls = List<String>.from(item['imageUrls'] ?? []);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: item['isNewProduct'] ? brandOrange.withOpacity(0.5) : Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _showImageOptionsBottomSheet(index, item['mappedName']),
                                child: Container(
                                  width: 55, height: 55,
                                  decoration: BoxDecoration(
                                    color: bgSoftColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: productUrls.isNotEmpty
                                        ? Image.network(productUrls.first, fit: BoxFit.cover)
                                        : Icon(Icons.add_a_photo_rounded, color: Colors.grey.shade400, size: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['mappedName'],
                                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: primaryNavy, height: 1.2),
                                    ),
                                    if (item['isNewProduct'])
                                      Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: brandOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text('جديد', style: TextStyle(color: brandOrange, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
                                  ],
                                ),
                              ),
                              IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 22),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    setState(() => _invoiceItems.removeAt(index));
                                  }
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: _buildCenteredInput(
                                  label: 'الكمية (كرتونة)',
                                  controller: item['qtyController'],
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildCenteredInput(
                                  label: 'عدد القطع بالكرتونة',
                                  controller: item['conversionFactorController'],
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCenteredInput(
                                  label: 'سعر الشراء (للكرتونة)',
                                  controller: item['priceController'],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildCenteredInput(
                                  label: 'سعر البيع (للقطعة)',
                                  controller: item['sellingPriceController'],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textInputAction: TextInputAction.done,
                                  labelColor: brandOrange,
                                  fillColor: Colors.orange.withOpacity(0.08),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: primaryNavy, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('إجمالي الفاتورة:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white70)),
                          Text('${_totalAmount.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 22, color: brandOrange)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _invoiceItems.isEmpty ? null : _saveInvoice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandOrange,
                            disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                          label: const Text('اعتماد الفاتورة وتحديث المخزون', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}