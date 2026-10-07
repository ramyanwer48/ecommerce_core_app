import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../logic/add_product_cubit.dart';
import '../logic/add_product_state.dart';
import 'widgets/google_image_picker_dialog.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? productData;

  const AddProductScreen({super.key, this.productData});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _descController = TextEditingController();
  final _variationsController = TextEditingController();

  final Color appPrimaryColor = const Color(0xFF0B1E3F);
  final Color appSecondaryColor = const Color(0xFFFF9F0A);

  String? _selectedMainCategory;
  String? _selectedSubCategory;
  List<String> _currentSubCategories = [];

  bool _inStock = true;
  bool _isDownloadingGoogleImage = false;
  bool _isUpdating = false;

  File? _selectedImage;
  List<File> _extraImages = [];

  String? _existingMainImageUrl;
  List<String> _existingExtraImageUrls = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.productData != null) {
      final data = widget.productData!;
      _nameController.text = data['name'] ?? '';
      _priceController.text = (data['price'] ?? 0).toString();
      _costPriceController.text = (data['costPrice'] ?? 0).toString();
      _stockController.text = (data['stockQuantity'] ?? 0).toString();
      _descController.text = data['description'] ?? '';
      _variationsController.text = (data['variations'] as List<dynamic>?)?.join(', ') ?? '';

      _inStock = data['isActive'] ?? data['inStock'] ?? true;
      _selectedMainCategory = data['category'];
      _selectedSubCategory = data['subCategory'];

      _existingMainImageUrl = data['imageUrl'];

      List<dynamic>? dbImages = data['imageUrls'] ?? data['images'];

      if (dbImages != null && dbImages.isNotEmpty) {
        if (_existingMainImageUrl == null || _existingMainImageUrl!.isEmpty) {
          _existingMainImageUrl = dbImages.first.toString();
        }

        _existingExtraImageUrls = dbImages.map((e) => e.toString()).toList();
        if (_existingMainImageUrl != null) {
          _existingExtraImageUrls.remove(_existingMainImageUrl);
        }
      }
    }
  }

  Future<void> _pickMainImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _existingMainImageUrl = null;
      });
    }
  }

  Future<void> _pickExtraImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        for (var img in images) {
          _extraImages.add(File(img.path));
        }
      });
    }
  }

  void _onSearchImagePressed() async {
    String productName = _nameController.text.trim();

    if (productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء كتابة اسم المنتج أولاً للبحث عن صوره!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.orange),
      );
      return;
    }

    final selectedImageUrls = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GoogleImagePickerDialog(productName: productName),
    );

    if (selectedImageUrls != null && selectedImageUrls.isNotEmpty) {
      setState(() => _isDownloadingGoogleImage = true);

      try {
        final documentDirectory = await getTemporaryDirectory();

        for (int i = 0; i < selectedImageUrls.length; i++) {
          final response = await http.get(Uri.parse(selectedImageUrls[i]));
          final file = File('${documentDirectory.path}/google_img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
          await file.writeAsBytes(response.bodyBytes);

          setState(() {
            if (i == 0 && _selectedImage == null && _existingMainImageUrl == null) {
              _selectedImage = file;
            } else {
              _extraImages.add(file);
            }
          });
        }

        setState(() => _isDownloadingGoogleImage = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم جلب ${selectedImageUrls.length} صور بنجاح! ✅', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        setState(() => _isDownloadingGoogleImage = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ أثناء معالجة الصور: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _updateProductDirectly() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برجاء إكمال جميع الحقول الإلزامية المطلوبة باللون الأحمر', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      return;
    }

    bool hasAnyImage = _selectedImage != null ||
        (_existingMainImageUrl != null && _existingMainImageUrl!.isNotEmpty) ||
        _extraImages.isNotEmpty ||
        _existingExtraImageUrls.isNotEmpty;

    if (!hasAnyImage) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الصورة الرئيسية إلزامية: الرجاء اختيار صورة للمنتج', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      return;
    }

    if (_selectedMainCategory == null || _selectedSubCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('التصنيفات إلزامية: الرجاء اختيار التصنيف الأساسي والفرعي', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isUpdating = true);

    try {
      String? finalMainImageUrl = _existingMainImageUrl;
      List<String> finalExtraUrls = List.from(_existingExtraImageUrls);

      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance.ref().child('products_images/${DateTime.now().millisecondsSinceEpoch}_main.jpg');
        await ref.putFile(_selectedImage!);
        finalMainImageUrl = await ref.getDownloadURL();
      }

      for (var file in _extraImages) {
        final ref = FirebaseStorage.instance.ref().child('products_images/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}');
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        finalExtraUrls.add(url);
      }

      List<String> variationsList = _variationsController.text.isNotEmpty
          ? _variationsController.text.split(',').map((e) => e.trim()).toList()
          : [];

      List<String> allImages = [];
      if (finalMainImageUrl != null && finalMainImageUrl.isNotEmpty) {
        allImages.add(finalMainImageUrl);
      } else if (finalExtraUrls.isNotEmpty) {
        finalMainImageUrl = finalExtraUrls.first;
        allImages.add(finalMainImageUrl);
        finalExtraUrls.removeAt(0);
      }
      allImages.addAll(finalExtraUrls);

      await FirebaseFirestore.instance.collection('products').doc(widget.productData!['id']).update({
        'name': _nameController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0,
        'costPrice': double.tryParse(_costPriceController.text) ?? 0,
        'stockQuantity': int.tryParse(_stockController.text) ?? 0,
        'category': _selectedMainCategory,
        'subCategory': _selectedSubCategory,
        'description': _descController.text.trim(),
        'variations': variationsList,
        'isActive': _inStock,
        'inStock': _inStock,
        'imageUrl': finalMainImageUrl,
        'imageUrls': allImages,
        'images': allImages,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث المنتج بنجاح! ✅', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء التحديث: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _descController.dispose();
    _variationsController.dispose();
    super.dispose();
  }

  // 🚀 دالة لرسم حقول الإدخال بشكل فخم ومريح
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    Color? iconColor,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade600),
          prefixIcon: icon != null ? Icon(icon, color: iconColor ?? appSecondaryColor, size: 22) : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appSecondaryColor, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.productData != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA), // لون خلفية هادي يبرز الكروت البيضاء
        appBar: AppBar(
          title: Text(isEditMode ? 'تعديل بيانات المنتج' : 'إضافة منتج جديد', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
          backgroundColor: appPrimaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: BlocConsumer<AddProductCubit, AddProductState>(
          listener: (context, state) {
            if (state is AddProductSuccess && !isEditMode) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم رفع الصور ونشر المنتج بنجاح! 🚀', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
              );
              _formKey.currentState?.reset();
              _nameController.clear();
              _priceController.clear();
              _costPriceController.clear();
              _stockController.text = '0';
              _descController.clear();
              _variationsController.clear();
              setState(() {
                _inStock = true;
                _selectedImage = null;
                _selectedMainCategory = null;
                _selectedSubCategory = null;
                _currentSubCategories.clear();
                _extraImages.clear();
              });
            } else if (state is AddProductError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
            }
          },
          builder: (context, state) {
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 🚀 منطقة الصورة الرئيسية
                  Row(
                    children: [
                      Icon(Icons.image_outlined, color: appPrimaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text('الصورة الرئيسية للمنتج', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: appPrimaryColor, fontSize: 15)),
                      const Text(' *', style: TextStyle(color: Colors.red, fontSize: 16)), // النجمة الحمراء
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
                      border: Border.all(color: _selectedImage == null && _existingMainImageUrl == null ? Colors.red.shade200 : Colors.transparent),
                    ),
                    child: _isDownloadingGoogleImage
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: appSecondaryColor),
                        const SizedBox(height: 16),
                        const Text('جاري سحب الصور...', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    )
                        : _selectedImage != null
                        ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_selectedImage!, fit: BoxFit.cover)),
                        Positioned(
                          top: 12, left: 12,
                          child: InkWell(
                            onTap: () => setState(() => _selectedImage = null),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]),
                              child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            ),
                          ),
                        ),
                      ],
                    )
                        : (_existingMainImageUrl != null && _existingMainImageUrl!.isNotEmpty)
                        ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(_existingMainImageUrl!, fit: BoxFit.cover)),
                        Positioned(
                          top: 12, left: 12,
                          child: InkWell(
                            onTap: () => setState(() => _existingMainImageUrl = null),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]),
                              child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            ),
                          ),
                        ),
                      ],
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickMainImage,
                            borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: appSecondaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.photo_library_outlined, size: 30, color: appSecondaryColor)),
                                const SizedBox(height: 12),
                                const Text('المعرض', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        Container(width: 1, height: 120, color: Colors.grey.shade200),
                        Expanded(
                          child: InkWell(
                            onTap: _onSearchImagePressed,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.travel_explore, size: 30, color: Colors.blue)),
                                const SizedBox(height: 12),
                                const Text('بحث جوجل', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🚀 معرض الصور الإضافية
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.collections_outlined, color: appPrimaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text('صور إضافية', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: appPrimaryColor, fontSize: 15)),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _pickExtraImages,
                        style: TextButton.styleFrom(foregroundColor: appSecondaryColor),
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                        label: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (_existingExtraImageUrls.isNotEmpty || _extraImages.isNotEmpty)
                    Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ..._existingExtraImageUrls.map((url) => Container(
                            margin: const EdgeInsets.only(left: 12),
                            width: 100,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, fit: BoxFit.cover)),
                                Positioned(
                                  top: 4, left: 4,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _existingExtraImageUrls.remove(url)),
                                    child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)]), child: const Icon(Icons.close, size: 14, color: Colors.red)),
                                  ),
                                ),
                              ],
                            ),
                          )),
                          ..._extraImages.map((file) => Container(
                            margin: const EdgeInsets.only(left: 12),
                            width: 100,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(file, fit: BoxFit.cover)),
                                Positioned(
                                  top: 4, left: 4,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _extraImages.remove(file)),
                                    child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)]), child: const Icon(Icons.close, size: 14, color: Colors.red)),
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  if (_existingExtraImageUrls.isEmpty && _extraImages.isEmpty) const SizedBox(height: 12),

                  // 🚀 حقول البيانات (فخمة ومنظمة)
                  _buildModernTextField(
                    controller: _nameController,
                    label: 'اسم المنتج *',
                    icon: Icons.inventory_2_outlined,
                    iconColor: appPrimaryColor,
                    validator: (value) => value == null || value.trim().isEmpty ? 'برجاء إدخال اسم المنتج' : null,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _buildModernTextField(
                          controller: _costPriceController,
                          label: 'سعر التكلفة *',
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: Colors.orange.shade700,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'مطلوب';
                            if ((double.tryParse(value) ?? 0) <= 0) return 'خطأ';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildModernTextField(
                          controller: _priceController,
                          label: 'سعر البيع *',
                          icon: Icons.sell_outlined,
                          iconColor: Colors.green.shade700,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'مطلوب';
                            if ((double.tryParse(value) ?? 0) <= 0) return 'خطأ';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  _buildModernTextField(
                    controller: _stockController,
                    label: 'الكمية الافتتاحية في المخزن *',
                    icon: Icons.view_in_ar_outlined,
                    iconColor: appPrimaryColor,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'الكمية مطلوبة';
                      if ((int.tryParse(value) ?? -1) < 0) return 'يجب إدخال رقم صحيح';
                      return null;
                    },
                  ),

                  // 🚀 منطقة التصنيفات (Dropdowns)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))]),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: LinearProgressIndicator(color: appSecondaryColor));
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text('⚠️ لا توجد أقسام مسجلة. قم بإضافتها أولاً.', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold));

                        final docs = snapshot.data!.docs;
                        List<String> mainCategories = docs.map((doc) => doc.id).toList();

                        if (_selectedMainCategory != null && !mainCategories.contains(_selectedMainCategory)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() { _selectedMainCategory = null; _selectedSubCategory = null; _currentSubCategories.clear(); });
                          });
                        } else if (_selectedMainCategory != null && mainCategories.contains(_selectedMainCategory)) {
                          final docData = docs.firstWhere((d) => d.id == _selectedMainCategory).data() as Map<String, dynamic>;
                          _currentSubCategories = List<String>.from(docData['subCategories'] ?? ['General']);
                          if (_selectedSubCategory != null && !_currentSubCategories.contains(_selectedSubCategory)) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() { _selectedSubCategory = null; });
                            });
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('تصنيف المنتج *', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: appPrimaryColor, fontSize: 13)),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: (mainCategories.contains(_selectedMainCategory)) ? _selectedMainCategory : null,
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: appPrimaryColor),
                              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'اختر القسم الأساسي',
                                hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade500),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              items: mainCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedMainCategory = val;
                                  _selectedSubCategory = null;
                                  final docData = docs.firstWhere((d) => d.id == val).data() as Map<String, dynamic>;
                                  _currentSubCategories = List<String>.from(docData['subCategories'] ?? ['General']);
                                });
                              },
                              validator: (value) => value == null ? 'مطلوب' : null,
                            ),

                            if (_selectedMainCategory != null && _currentSubCategories.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: (_currentSubCategories.contains(_selectedSubCategory)) ? _selectedSubCategory : null,
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down_rounded, color: appSecondaryColor),
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black87),
                                decoration: InputDecoration(
                                  hintText: 'اختر القسم الفرعي',
                                  hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade500),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                items: _currentSubCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                                onChanged: (val) => setState(() => _selectedSubCategory = val),
                                validator: (value) => value == null ? 'مطلوب' : null,
                              ),
                            ]
                          ],
                        );
                      },
                    ),
                  ),

                  _buildModernTextField(
                    controller: _variationsController,
                    label: 'خيارات الهاردوير (اختياري)',
                    hintText: 'مثال: 16GB, 32GB (افصل بفاصلة)',
                    icon: Icons.memory_outlined,
                    iconColor: Colors.purple.shade300,
                  ),

                  _buildModernTextField(
                    controller: _descController,
                    label: 'الوصف الخاص بالمنتج *',
                    icon: Icons.description_outlined,
                    iconColor: Colors.blue.shade400,
                    maxLines: 4,
                    validator: (value) => value == null || value.trim().isEmpty ? 'برجاء كتابة وصف للمنتج' : null,
                  ),

                  // 🚀 زر الإتاحة (مدمج في كارت)
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: SwitchListTile(
                      title: const Text('متوفر في المخزن ومتاح للبيع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                      value: _inStock,
                      activeColor: Colors.white,
                      activeTrackColor: Colors.green,
                      inactiveTrackColor: Colors.grey.shade300,
                      onChanged: (val) => setState(() => _inStock = val),
                    ),
                  ),

                  // 🚀 زر الحفظ العريض والفخم
                  (state is AddProductLoading || _isUpdating)
                      ? Center(child: CircularProgressIndicator(color: appSecondaryColor))
                      : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (isEditMode) {
                        _updateProductDirectly();
                      } else {
                        if (!_formKey.currentState!.validate()) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برجاء إكمال جميع الحقول الإلزامية المطلوبة باللون الأحمر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
                          return;
                        }
                        if (_selectedImage == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الصورة الرئيسية إلزامية: الرجاء اختيار صورة للمنتج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
                          return;
                        }
                        if (_selectedMainCategory == null || _selectedSubCategory == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('التصنيفات إلزامية: الرجاء اختيار التصنيف الأساسي والفرعي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
                          return;
                        }

                        List<String> variationsList = _variationsController.text.isNotEmpty ? _variationsController.text.split(',').map((e) => e.trim()).toList() : [];

                        context.read<AddProductCubit>().addProductToFirestore(
                          name: _nameController.text,
                          price: double.parse(_priceController.text),
                          costPrice: double.parse(_costPriceController.text),
                          category: _selectedMainCategory!,
                          subCategory: _selectedSubCategory!,
                          description: _descController.text,
                          mainImageFile: _selectedImage!,
                          extraImageFiles: _extraImages,
                          variations: variationsList,
                          inStock: _inStock,
                          stockQuantity: int.tryParse(_stockController.text.trim()) ?? 0,
                        );
                      }
                    },
                    icon: Icon(isEditMode ? Icons.save_rounded : Icons.cloud_upload_rounded, color: Colors.white),
                    label: Text(isEditMode ? 'حفظ التعديلات' : 'نشر المنتج', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}