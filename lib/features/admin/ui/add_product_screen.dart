import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 إضافة مكتبة الفايربيز
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
  final _descController = TextEditingController();
  final _variationsController = TextEditingController();

  // 👈 التعديل الأول: جعلنا القسم المختار يقبل (null) في البداية حتى يتم تحميل البيانات
  String? _selectedCategory;
  bool _inStock = true;

  // الصورة الأساسية
  File? _selectedImage;
  // قائمة الصور الإضافية من الموبايل
  List<File> _extraImages = [];

  final ImagePicker _picker = ImagePicker();

  // اختيار الصورة الأساسية
  Future<void> _pickMainImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  // اختيار عدة صور إضافية معاً
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
    _descController.dispose();
    _variationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('إضافة منتج جديد', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<AddProductCubit, AddProductState>(
        listener: (context, state) {
          if (state is AddProductSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم رفع الصور ونشر المنتج بنجاح! 🚀'), backgroundColor: Colors.green),
            );
            _formKey.currentState?.reset();
            _nameController.clear();
            _priceController.clear();
            _descController.clear();
            _variationsController.clear();
            setState(() {
              _inStock = true;
              _selectedImage = null;
              _selectedCategory = null; // 👈 تصفير الاختيار بعد النجاح
              _extraImages.clear();
            });
          } else if (state is AddProductError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
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
                const Text('الصورة الرئيسية للمنتج:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickMainImage,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF00D4FF), width: 1.5),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                        : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 40, color: Color(0xFF00D4FF)),
                        SizedBox(height: 8),
                        Text('اضغط لاختيار الصورة الرئيسية', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. اختيار صور إضافية للمعرض
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('معرض الصور الإضافية:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _pickExtraImages,
                      icon: const Icon(Icons.add_photo_alternate, color: Color(0xFF007BFF)),
                      label: Text('اختر (${_extraImages.length}) صور', style: const TextStyle(color: Color(0xFF007BFF))),
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
                          margin: const EdgeInsets.only(right: 8),
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
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'السعر', border: OutlineInputBorder()),
                  validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 12),

                // 👇 التعديل الجوهري: StreamBuilder لجلب الأقسام ديناميكياً 👇
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('categories')
                      .where('isActive', isEqualTo: true) // جلب الأقسام النشطة فقط
                      .orderBy('orderIndex')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: LinearProgressIndicator(color: Color(0xFF00D4FF)));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Text('⚠️ لا توجد أقسام متاحة. الرجاء إضافة قسم من إدارة الأقسام أولاً.', style: TextStyle(color: Colors.red));
                    }

                    // استخراج الأسماء من قاعدة البيانات
                    final List<String> dynamicCategories = snapshot.data!.docs
                        .map((doc) => doc['name'] as String)
                        .toList();

                    // التأكد من أن القسم المختار موجود في القائمة، وإلا نختار أول عنصر كافتراضي
                    if (_selectedCategory == null || !dynamicCategories.contains(_selectedCategory)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _selectedCategory = dynamicCategories.first;
                        });
                      });
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
                      items: dynamicCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val),
                      validator: (value) => value == null ? 'الرجاء اختيار قسم' : null,
                    );
                  },
                ),
                // 👆 نهاية التعديل 👆

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
                  title: const Text('متوفر في المخزن'),
                  value: _inStock,
                  onChanged: (val) => setState(() => _inStock = val),
                ),
                const SizedBox(height: 24),
                state is AddProductLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    if (_selectedImage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الرجاء اختيار الصورة الرئيسية للمنتج أولاً'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (_selectedCategory == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الرجاء اختيار القسم أولاً'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (_formKey.currentState!.validate()) {
                      List<String> variationsList = _variationsController.text.isNotEmpty
                          ? _variationsController.text.split(',').map((e) => e.trim()).toList()
                          : [];

                      context.read<AddProductCubit>().addProductToFirestore(
                        name: _nameController.text,
                        price: double.parse(_priceController.text),
                        category: _selectedCategory!, // 👈 تأكيد إرسال القسم
                        description: _descController.text,
                        mainImageFile: _selectedImage!,
                        extraImageFiles: _extraImages,
                        variations: variationsList,
                        inStock: _inStock,
                      );
                    }
                  },
                  child: const Text('نشر المنتج', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}