import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _descController = TextEditingController();
  final _variationsController = TextEditingController();

  // 🚀 إضافة FocusNodes لتسريع التنقل بين الحقول ومنع الـ Rebuild العشوائي
  final _nameFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _descFocus = FocusNode();
  final _variationsFocus = FocusNode();

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

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _variationsController.dispose();
    _nameFocus.dispose();
    _priceFocus.dispose();
    _descFocus.dispose();
    _variationsFocus.dispose();
    super.dispose();
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
    if (!_formKey.currentState!.validate()) return;
    bool hasAnyImage = _selectedImage != null || (_existingMainImageUrl != null && _existingMainImageUrl!.isNotEmpty) || _extraImages.isNotEmpty || _existingExtraImageUrls.isNotEmpty;
    if (!hasAnyImage) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الصورة الرئيسية إلزامية', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
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

      List<String> variationsList = _variationsController.text.isNotEmpty ? _variationsController.text.split(',').map((e) => e.trim()).toList() : [];

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
        'category': _selectedMainCategory,
        'subCategory': _selectedSubCategory,
        'description': _descController.text.trim(),
        'variations': variationsList,
        'isActive': _inStock,
        'imageUrl': finalMainImageUrl,
        'imageUrls': allImages,
        'images': allImages,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح! ✅', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showCategorySheet(String title, List<String> items, String? selectedItem, Function(String) onSelect) {
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 40),
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
                  const SizedBox(width: 48),
                  Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: appPrimaryColor)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 28),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.builder(
                  shrinkWrap: true,
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
                      tileColor: isSelected ? appSecondaryColor.withOpacity(0.1) : Colors.transparent,
                      title: Text(item, style: TextStyle(fontFamily: 'Cairo', fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? appSecondaryColor : Colors.black87)),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: appSecondaryColor) : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernSelectionField({required String label, required String hint, required String? value, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: appPrimaryColor, fontSize: 14)),
        const SizedBox(height: 8),
        FormField<String>(
          initialValue: value,
          validator: (val) => value == null ? 'مطلوب' : null,
          builder: (FormFieldState<String> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: state.hasError ? Colors.red : (value != null ? appSecondaryColor : Colors.grey.shade300),
                          width: state.hasError || value != null ? 1.5 : 1.0
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(value ?? hint, style: TextStyle(fontFamily: 'Cairo', fontWeight: value != null ? FontWeight.bold : FontWeight.w600, color: value != null ? appPrimaryColor : Colors.grey.shade500, fontSize: 14), overflow: TextOverflow.ellipsis)),
                        Icon(Icons.keyboard_arrow_down_rounded, color: value != null ? appSecondaryColor : Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 12),
                    child: Text(state.errorText!, style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  )
              ],
            );
          },
        ),
      ],
    );
  }

  // 🚀 الحقل المحدث بالأداء العالي (بدون Shadow ومع FocusNode)
  Widget _buildModernTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    IconData? icon,
    Color? iconColor,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    int maxLines = 1,
    String? hintText,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          helperText: helperText,
          helperStyle: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold),
          labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade600),
          prefixIcon: icon != null ? Icon(icon, color: iconColor ?? appSecondaryColor, size: 22) : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appSecondaryColor, width: 1.5)),
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
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(isEditMode ? 'تعديل بيانات المنتج' : 'إضافة منتج للكتالوج', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
          backgroundColor: appPrimaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
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
        // 🚀 استخدام CustomScrollView لتحسين الأداء بشكل جذري أثناء ظهور الكيبورد
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(), // إخفاء الكيبورد عند الضغط في أي مكان فارغ
          child: Form(
            key: _formKey,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        children: [
                          Icon(Icons.image_outlined, color: appPrimaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text('الصورة الرئيسية للمنتج', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: appPrimaryColor, fontSize: 15)),
                          const Text(' *', style: TextStyle(color: Colors.red, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: appSecondaryColor, width: 2),
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
                            ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_selectedImage!, fit: BoxFit.cover)),
                            Positioned(
                              top: 12, left: 12,
                              child: InkWell(
                                onTap: () => setState(() => _selectedImage = null),
                                child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]), child: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
                              ),
                            ),
                          ],
                        )
                            : (_existingMainImageUrl != null && _existingMainImageUrl!.isNotEmpty)
                            ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(_existingMainImageUrl!, fit: BoxFit.cover)),
                            Positioned(
                              top: 12, left: 12,
                              child: InkWell(
                                onTap: () => setState(() => _existingMainImageUrl = null),
                                child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]), child: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
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
                                borderRadius: const BorderRadius.only(topRight: Radius.circular(14), bottomRight: Radius.circular(14)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: appSecondaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.photo_library_rounded, size: 32, color: appSecondaryColor)),
                                    const SizedBox(height: 12),
                                    Text('المعرض', style: TextStyle(color: appSecondaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                            Container(width: 1, height: 120, color: appSecondaryColor.withOpacity(0.3)),
                            Expanded(
                              child: InkWell(
                                onTap: _onSearchImagePressed,
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: appSecondaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.travel_explore_rounded, size: 32, color: appSecondaryColor)),
                                    const SizedBox(height: 12),
                                    Text('بحث جوجل', style: TextStyle(color: appSecondaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildModernTextField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        label: 'اسم المنتج *',
                        icon: Icons.inventory_2_outlined,
                        iconColor: appPrimaryColor,
                        validator: (value) => value == null || value.trim().isEmpty ? 'برجاء إدخال اسم المنتج' : null,
                      ),

                      _buildModernTextField(
                        controller: _priceController,
                        focusNode: _priceFocus,
                        label: 'سعر البيع للعميل *',
                        icon: Icons.sell_outlined,
                        iconColor: Colors.green.shade700,
                        keyboardType: TextInputType.number,
                        validator: (value) => value == null || value.trim().isEmpty || (double.tryParse(value) ?? 0) <= 0 ? 'سعر غير صالح' : null,
                      ),

                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: appSecondaryColor));
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text('لا توجد أقسام مسجلة');

                            final docs = snapshot.data!.docs;
                            List<String> mainCategories = docs.map((doc) => doc.id).toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildModernSelectionField(
                                  label: 'التصنيف الأساسي *',
                                  hint: 'اضغط لاختيار القسم الأساسي',
                                  value: _selectedMainCategory,
                                  onTap: () {
                                    _showCategorySheet('اختر التصنيف الأساسي', mainCategories, _selectedMainCategory, (val) {
                                      setState(() {
                                        _selectedMainCategory = val;
                                        _selectedSubCategory = null;
                                        final docData = docs.firstWhere((d) => d.id == val).data() as Map<String, dynamic>;
                                        _currentSubCategories = List<String>.from(docData['subCategories'] ?? ['General']);
                                      });
                                    });
                                  },
                                ),
                                if (_selectedMainCategory != null && _currentSubCategories.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _buildModernSelectionField(
                                    label: 'التصنيف الفرعي *',
                                    hint: 'اضغط لاختيار القسم الفرعي',
                                    value: _selectedSubCategory,
                                    onTap: () {
                                      _showCategorySheet('اختر التصنيف الفرعي', _currentSubCategories, _selectedSubCategory, (val) {
                                        setState(() => _selectedSubCategory = val);
                                      });
                                    },
                                  ),
                                ]
                              ],
                            );
                          },
                        ),
                      ),

                      _buildModernTextField(
                        controller: _variationsController,
                        focusNode: _variationsFocus,
                        label: 'خيارات إضافية (اختياري)',
                        hintText: '16GB, 32GB',
                        icon: Icons.memory_outlined,
                        iconColor: Colors.purple.shade300,
                      ),

                      _buildModernTextField(
                        controller: _descController,
                        focusNode: _descFocus,
                        label: 'الوصف الخاص بالمنتج *',
                        icon: Icons.description_outlined,
                        maxLines: 4,
                        textInputAction: TextInputAction.done, // 👈 عشان يقفل الكيبورد بعد الوصف
                      ),

                      Container(
                        margin: const EdgeInsets.only(bottom: 32),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                        child: SwitchListTile(
                          title: const Text('مرئي في المتجر للعملاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                          value: _inStock,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.green,
                          onChanged: (val) => setState(() => _inStock = val),
                        ),
                      ),

                      _isUpdating
                          ? Center(child: CircularProgressIndicator(color: appSecondaryColor))
                          : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appSecondaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          if (isEditMode) {
                            _updateProductDirectly();
                          } else {
                            if (!_formKey.currentState!.validate()) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل الحقول المطلوبة', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                              return;
                            }
                            if (_selectedMainCategory == null || _selectedSubCategory == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برجاء اختيار التصنيفات الأساسية والفرعية', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                              return;
                            }

                            List<String> variationsList = _variationsController.text.isNotEmpty ? _variationsController.text.split(',').map((e) => e.trim()).toList() : [];
                            context.read<AddProductCubit>().addProductToFirestore(
                              name: _nameController.text,
                              price: double.parse(_priceController.text),
                              costPrice: 0.0,
                              category: _selectedMainCategory!,
                              subCategory: _selectedSubCategory!,
                              description: _descController.text,
                              mainImageFile: _selectedImage!,
                              extraImageFiles: _extraImages,
                              variations: variationsList,
                              inStock: _inStock,
                              stockQuantity: 0,
                            );
                          }
                        },
                        icon: Icon(isEditMode ? Icons.save_rounded : Icons.cloud_upload_rounded, color: Colors.white),
                        label: Text(isEditMode ? 'حفظ التعديلات' : 'نشر كارت المنتج', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}