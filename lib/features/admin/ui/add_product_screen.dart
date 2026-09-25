import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../logic/add_product_cubit.dart';
import '../logic/add_product_state.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

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

  // 🎨 ألوان الهوية
  final Color appPrimaryColor = const Color(0xFF0B1E3F);
  final Color appSecondaryColor = const Color(0xFFFF9F0A);

  String? _selectedMainCategory;
  String? _selectedSubCategory;
  List<String> _currentSubCategories = [];

  bool _inStock = true;

  File? _selectedImage;
  List<File> _extraImages = [];

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickMainImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _pickExtraImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _extraImages = images.map((img) => File(img.path)).toList();
      });
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('إضافة منتج جديد', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
          backgroundColor: appPrimaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: BlocConsumer<AddProductCubit, AddProductState>(
          listener: (context, state) {
            if (state is AddProductSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم رفع الصور ونشر المنتج بنجاح! 🚀', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
              );
            }
          },
          builder: (context, state) {
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. اختيار الصورة الأساسية
                  Text('الصورة الرئيسية للمنتج:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: appPrimaryColor)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickMainImage,
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: appSecondaryColor, width: 1.5),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 40, color: appSecondaryColor),
                          const SizedBox(height: 8),
                          const Text('اضغط لاختيار الصورة الرئيسية', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. اختيار صور إضافية للمعرض
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('معرض الصور الإضافية:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: appPrimaryColor)),
                      TextButton.icon(
                        onPressed: _pickExtraImages,
                        icon: Icon(Icons.add_photo_alternate, color: appPrimaryColor),
                        label: Text('اختر (${_extraImages.length}) صور', style: TextStyle(color: appPrimaryColor, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (_extraImages.isNotEmpty)
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _extraImages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_extraImages[index], fit: BoxFit.cover),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'اسم المنتج', border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),

                  // حقل سعر البيع للعميل
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سعر البيع للعميل (السعر الثابت)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sell_outlined, color: Colors.green),
                    ),
                    validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),

                  // حقل سعر التكلفة الجديد
                  TextFormField(
                    controller: _costPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سعر التكلفة للقطعة (عليك كتاجر)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: Colors.orange),
                    ),
                    validator: (value) => value!.isEmpty ? 'مطلوب لحساب الأرباح لاحقاً' : null,
                  ),
                  const SizedBox(height: 12),

                  // حقل الكمية في المخزون
                  TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الكمية الافتتاحية في المخزن',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),

                  // 🌟 القوائم المنسدلة للأقسام الأساسية والفرعية
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10)
                    ),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: LinearProgressIndicator(color: appSecondaryColor));
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text('⚠️ لا توجد أقسام مسجلة. قم بإضافتها من شاشة إدارة الأقسام.', style: TextStyle(color: Colors.red, fontFamily: 'Cairo'));
                        }

                        final docs = snapshot.data!.docs;
                        List<String> mainCategories = docs.map((doc) => doc.id).toList();

                        if (_selectedMainCategory != null && !mainCategories.contains(_selectedMainCategory)) {
                          _selectedMainCategory = null;
                          _selectedSubCategory = null;
                        }

                        return Column(
                          children: [
                            // 1. التصنيف الأساسي
                            // داخل StreamBuilder في شاشة add_product_screen.dart

// 1. التصنيف الأساسي
                            DropdownButtonFormField<String>(
                              value: _selectedMainCategory,
                              isExpanded: true, // 👈 هذا هو الحل السحري لمنع الخطأ الأصفر
                              decoration: const InputDecoration(labelText: 'التصنيف الأساسي', border: OutlineInputBorder()),
                              items: mainCategories.map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat, style: const TextStyle(fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis) // 👈 تأكيد إضافي لمنع القص
                              )).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedMainCategory = val;
                                  _selectedSubCategory = null;
                                  final docData = docs.firstWhere((d) => d.id == val).data() as Map<String, dynamic>;
                                  _currentSubCategories = List<String>.from(docData['subCategories'] ?? ['General']);
                                });
                              },
                              validator: (value) => value == null ? 'مطلوب اختيار تصنيف أساسي' : null,
                            ),
                            const SizedBox(height: 12),

// 2. التصنيف الفرعي
                            if (_selectedMainCategory != null)
                              DropdownButtonFormField<String>(
                                value: _selectedSubCategory,
                                isExpanded: true, // 👈 هنا أيضاً
                                decoration: const InputDecoration(labelText: 'التصنيف الفرعي', border: OutlineInputBorder()),
                                items: _currentSubCategories.map((cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat, style: const TextStyle(fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis)
                                )).toList(),
                                onChanged: (val) => setState(() => _selectedSubCategory = val),
                                validator: (value) => value == null ? 'مطلوب اختيار تصنيف فرعي' : null,
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _variationsController,
                    decoration: const InputDecoration(
                        labelText: 'خيارات الهاردوير (مثال: 16GB, 32GB - افصل بفاصلة ,)',
                        border: OutlineInputBorder()
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('متوفر في المخزن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    value: _inStock,
                    activeColor: appSecondaryColor,
                    onChanged: (val) => setState(() => _inStock = val),
                  ),
                  const SizedBox(height: 24),

                  state is AddProductLoading
                      ? Center(child: CircularProgressIndicator(color: appSecondaryColor))
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (_selectedImage == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('الرجاء اختيار الصورة الرئيسية للمنتج أولاً', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (_selectedMainCategory == null || _selectedSubCategory == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('الرجاء إكمال اختيار التصنيفات بالكامل', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (_formKey.currentState!.validate()) {
                        List<String> variationsList = _variationsController.text.isNotEmpty
                            ? _variationsController.text.split(',').map((e) => e.trim()).toList()
                            : [];

                        // 👈 هنا الحل: تمرير التصنيف الأساسي والفرعي بنجاح
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
                    child: const Text('نشر المنتج', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}