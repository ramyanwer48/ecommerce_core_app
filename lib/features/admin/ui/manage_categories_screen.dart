import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// 👈 تأكد من استدعاء الكيوبيت بتاعنا بالمسار الصحيح عندك
import '../logic/admin_categories_cubit.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  @override
  void initState() {
    super.initState();
    // جلب الأقسام أوتوماتيك أول ما الشاشة تفتح
    context.read<AdminCategoriesCubit>().loadCategories();
  }

  // 🪟 نافذة منبثقة لإضافة قسم جديد
  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final imageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (contextDialog) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إضافة قسم جديد 🆕', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'اسم القسم (مثال: عروض العيد)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: imageController,
                  decoration: InputDecoration(
                    labelText: 'رابط أيقونة القسم (اختياري)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextDialog),
              child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF), // الأزرق بتاعنا
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  // استدعاء دالة الإضافة من الكيوبيت
                  context.read<AdminCategoriesCubit>().addNewCategory(
                    name: nameController.text,
                    imageUrl: imageController.text,
                  );
                  Navigator.pop(contextDialog); // قفل النافذة
                }
              },
              child: const Text('حفظ ونشر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('إدارة الأقسام', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // زرار الإضافة العائم
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context),
        backgroundColor: const Color(0xFF00D4FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('قسم جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: BlocConsumer<AdminCategoriesCubit, AdminCategoriesState>(
        listener: (context, state) {
          if (state is AdminCategoriesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminCategoriesLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)));
          }

          if (state is AdminCategoriesLoaded) {
            final categories = state.categories;
            if (categories.isEmpty) {
              return const Center(
                child: Text('لا توجد أقسام.. أضف قسمك الأول!', style: TextStyle(fontSize: 18, color: Colors.grey)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: cat.imageUrl.isNotEmpty
                          ? Image.network(cat.imageUrl, width: 45, height: 45, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                          : Container(width: 45, height: 45, color: Colors.grey.shade200, child: const Icon(Icons.category, color: Colors.grey)),
                    ),
                    // لو القسم مخفي، اسمه هيتشطب عليه بخط عشان الأدمن يلاحظ بسرعة
                    title: Text(
                      cat.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: cat.isActive ? TextDecoration.none : TextDecoration.lineThrough,
                        color: cat.isActive ? Colors.black : Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      cat.isActive ? 'نشط (يظهر للعملاء)' : 'مخفي مؤقتاً',
                      style: TextStyle(color: cat.isActive ? Colors.green : Colors.red, fontSize: 12),
                    ),
                    // زرار الإخفاء والإظهار السريع (Toggle)
                    trailing: Switch(
                      value: cat.isActive,
                      activeColor: const Color(0xFF00D4FF),
                      onChanged: (value) {
                        context.read<AdminCategoriesCubit>().toggleStatus(cat.id, cat.isActive);
                      },
                    ),
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}