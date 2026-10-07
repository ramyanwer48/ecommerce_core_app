import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/address_model.dart';
import '../logic/address_cubit.dart';

class AddAddressBottomSheet extends StatefulWidget {
  const AddAddressBottomSheet({super.key});

  @override
  State<AddAddressBottomSheet> createState() => _AddAddressBottomSheetState();
}

class _AddAddressBottomSheetState extends State<AddAddressBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();

  bool _isDefault = false;

  String _selectedTitle = 'المنزل'; // الاختيار الافتراضي لنوع العنوان
  String? _selectedCity;

  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  final List<String> _egyptGovernorates = [
    'القاهرة', 'الجيزة', 'الإسكندرية', 'الشرقية', 'الدقهلية', 'القليوبية', 'المنوفية',
    'الغربية', 'البحيرة', 'كفر الشيخ', 'دمياط', 'الإسماعيلية', 'بورسعيد', 'السويس',
    'شمال سيناء', 'جنوب سيناء', 'الفيوم', 'بني سويف', 'المنيا', 'أسيوط', 'سوهاج',
    'قنا', 'الأقصر', 'أسوان', 'البحر الأحمر', 'الوادي الجديد', 'مطروح'
  ];

  final List<String> _titleOptions = ['المنزل', 'العمل', 'أخرى'];

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      final newAddress = AddressModel(
        id: '',
        title: _selectedTitle,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _selectedCity!,
        streetAddress: _streetController.text.trim(),
        isDefault: _isDefault,
      );

      context.read<AddressCubit>().addAddress(newAddress);
      Navigator.pop(context);
    } else {
      HapticFeedback.vibrate();
    }
  }

  // 🚀 تصميم أزرار الاختيار السريعة (بديل الـ Dropdown السخيف لنوع العنوان)
  Widget _buildTitleChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark_border_rounded, color: brandOrange, size: 20),
              const SizedBox(width: 8),
              const Text('نوع العنوان:', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _titleOptions.map((title) {
              bool isSelected = _selectedTitle == title;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTitle = title);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? brandOrange : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? brandOrange : Colors.grey.shade300, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isSelected ? Colors.white : primaryNavy,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: brandOrange, size: 22),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        ),
        validator: validator,
      ),
    );
  }

  // 🚀 تعديل القائمة المنسدلة لضمان محاذاة المحافظات لليمين
  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true, // 👈 دي اللي بتسمح للنص يروح يمين براحته
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: brandOrange, size: 22),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            alignment: Alignment.centerRight, // 👈 هنا بنجبر النص إنه يبدأ من اليمين
            child: Text(item, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: brandOrange.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(Icons.location_on_rounded, color: brandOrange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'إضافة عنوان توصيل',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: primaryNavy),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 26),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 🚀 1. تم تغيير الدروب بوكس بتاع نوع العنوان لأزرار سريعة شيك جداً
                  _buildTitleChips(),

                  _buildTextField(
                    controller: _fullNameController,
                    label: 'الاسم الكامل للمستلم',
                    icon: Icons.person_outline_rounded,
                    validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المستلم' : null,
                  ),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'رقم هاتف التواصل',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.trim().length < 10 ? 'يرجى إدخال رقم هاتف صحيح' : null,
                  ),

                  // 🚀 2. المحافظات اتظبطت وبقت لليمين 100%
                  _buildDropdownField(
                    label: 'المدينة / المحافظة',
                    icon: Icons.location_city_rounded,
                    value: _selectedCity,
                    items: _egyptGovernorates,
                    onChanged: (val) {
                      setState(() => _selectedCity = val);
                    },
                    validator: (v) => v == null || v.isEmpty ? 'يرجى اختيار المحافظة' : null,
                  ),

                  _buildTextField(
                    controller: _streetController,
                    label: 'تفاصيل العنوان (الشارع، العمارة، الطابق)',
                    icon: Icons.home_work_outlined,
                    maxLines: 2,
                    validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال تفاصيل العنوان' : null,
                  ),

                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: CheckboxListTile(
                      title: const Text('تعيين كعنوان استلام افتراضي', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                      value: _isDefault,
                      activeColor: brandOrange,
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onChanged: (val) => setState(() => _isDefault = val ?? false),
                    ),
                  ),

                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryNavy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'حفظ العنوان وإضافته',
                      style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}