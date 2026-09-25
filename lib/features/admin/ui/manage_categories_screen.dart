import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🎨 ألوان الهوية الخاصة بك
  final Color appPrimaryColor = const Color(0xFF0B1E3F);
  final Color appSecondaryColor = const Color(0xFFFF9F0A);
  final Color appBackgroundColor = const Color(0xFFF4F6F9);

  // 🪟 إضافة تصنيف أساسي جديد
  void _showAddMainCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (contextDialog) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('إضافة تصنيف أساسي 🆕', style: TextStyle(fontWeight: FontWeight.bold, color: appPrimaryColor, fontFamily: 'Cairo')),
          content: TextField(
            controller: nameController,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'اسم التصنيف بالإنجليزية (مثال: Laptops)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextDialog),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: appSecondaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                String newMain = nameController.text.trim();
                if (newMain.isNotEmpty) {
                  await _firestore.collection('categories').doc(newMain).set({
                    'name': newMain,
                    'subCategories': ['General'],
                  }, SetOptions(merge: true));

                  if (contextDialog.mounted) {
                    Navigator.pop(contextDialog);
                  }
                }
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ),
          ],
        );
      },
    );
  }

  // 🪟 إضافة تصنيف فرعي داخل قسم أساسي
  void _showAddSubCategoryDialog(BuildContext context, String mainCategoryDocId) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (contextDialog) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('فرعي لـ ($mainCategoryDocId)', style: TextStyle(fontWeight: FontWeight.bold, color: appPrimaryColor, fontFamily: 'Cairo', fontSize: 16), textAlign: TextAlign.center),
          content: TextField(
            controller: nameController,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'اسم التصنيف الفرعي',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextDialog),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                String newSub = nameController.text.trim();
                if (newSub.isNotEmpty) {
                  await _firestore.collection('categories').doc(mainCategoryDocId).update({
                    'subCategories': FieldValue.arrayUnion([newSub])
                  });

                  if (contextDialog.mounted) {
                    Navigator.pop(contextDialog);
                  }
                }
              },
              child: const Text('إضافة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ),
          ],
        );
      },
    );
  }

  // 🗑️ حذف تصنيف فرعي
  void _deleteSubCategory(String mainCategoryDocId, String subCategory) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo')),
          content: Text('هل أنت متأكد من حذف التصنيف الفرعي "$subCategory"؟', style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await _firestore.collection('categories').doc(mainCategoryDocId).update({
                  'subCategories': FieldValue.arrayRemove([subCategory])
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حذف', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            )
          ],
        )
    );
  }

  // 🗑️ حذف تصنيف أساسي بالكامل
  void _deleteMainCategory(String mainCategoryDocId) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تحذير شديد!', style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text('سيتم حذف التصنيف الأساسي "$mainCategoryDocId" وكل تصنيفاته الفرعية. هل أنت متأكد؟', style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await _firestore.collection('categories').doc(mainCategoryDocId).delete();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('نعم، احذف', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // 👈 جعل الاتجاه عربي بالكامل
      child: Scaffold(
        backgroundColor: appBackgroundColor,
        appBar: AppBar(
          title: const Text('إدارة الأقسام', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
          centerTitle: true,
          backgroundColor: appPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),

        // 👈 تم تعديل مكان الزر ليصبح في أسفل اليمين
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddMainCategoryDialog(context),
          backgroundColor: appSecondaryColor,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('تصنيف أساسي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ),

        body: Column(
          children: [
            // 📋 عرض الأقسام من فايربيز
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('categories').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: appSecondaryColor));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('لا توجد أقسام مسجلة. قم إضافة تصنيف أساسي.', style: TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'Cairo')),
                    );
                  }

                  final categories = snapshot.data!.docs;

                  return ListView.builder(
                    // 👇 التعديل هنا: أضفنا مساحة (bottom: 90) لرفع الكارت الأخير فوق الزر
                    padding: const EdgeInsets.only(top: 12, right: 12, left: 12, bottom: 90),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final doc = categories[index];
                      // ... باقي الكود كما هو
                      final data = doc.data() as Map<String, dynamic>;

                      String mainCategoryName = data['name'] ?? doc.id;
                      List<dynamic> subCategoriesRaw = data['subCategories'] ?? [];
                      List<String> subCategories = List<String>.from(subCategoriesRaw);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade300)
                        ),
                        elevation: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // رأس الكارت
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                  color: appPrimaryColor.withValues(alpha: 0.05),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16))
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(Icons.category, color: appPrimaryColor, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            mainCategoryName,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: appPrimaryColor, fontFamily: 'Cairo'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                                    onPressed: () => _deleteMainCategory(doc.id),
                                    tooltip: 'حذف التصنيف الأساسي',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                ],
                              ),
                            ),

                            // جسم الكارت: التصنيفات الفرعية (Chips)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('التصنيفات الفرعية:', style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: subCategories.map((sub) {
                                      return Chip(
                                        label: Text(sub, style: const TextStyle(fontSize: 13)),
                                        deleteIcon: const Icon(Icons.cancel, size: 18),
                                        onDeleted: () => _deleteSubCategory(doc.id, sub),
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(color: Colors.grey.shade300)
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 12),

                                  // زر إضافة تصنيف فرعي
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => _showAddSubCategoryDialog(context, doc.id),
                                      icon: Icon(Icons.add_circle_outline, color: appSecondaryColor, size: 18),
                                      label: Text('إضافة فرعي', style: TextStyle(color: appSecondaryColor, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                      style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          backgroundColor: appSecondaryColor.withValues(alpha: 0.1),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ],
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
}