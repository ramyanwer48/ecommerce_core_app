import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Color appPrimaryColor = const Color(0xFF0B1E3F);
  final Color appSecondaryColor = const Color(0xFFFF9F0A);
  final Color appBackgroundColor = const Color(0xFFF4F6F9);

  // 🪟 إضافة تصنيف أساسي جديد (تم تحويله إلى Bottom Sheet سلس وسريع)
  void _showAddMainCategoryModal(BuildContext context) {
    final nameController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (contextModal, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        Text('إضافة تصنيف أساسي جديد', style: TextStyle(fontWeight: FontWeight.bold, color: appPrimaryColor, fontFamily: 'Cairo', fontSize: 18)),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black87, width: 1.2)),
                            child: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
                          ),
                        )
                      ],
                    ),
                    const Divider(height: 20),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(fontFamily: 'Cairo'),
                      decoration: InputDecoration(
                        labelText: 'اسم التصنيف (مثال: Laptops)',
                        labelStyle: const TextStyle(fontFamily: 'Cairo'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appSecondaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: isSaving ? null : () async {
                        String newMain = nameController.text.trim();
                        if (newMain.isNotEmpty) {
                          setModalState(() => isSaving = true);
                          await _firestore.collection('categories').doc(newMain).set({
                            'name': newMain,
                            'subCategories': ['General'],
                          }, SetOptions(merge: true));

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        }
                      },
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('حفظ التصنيف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 🪟 إضافة تصنيف فرعي داخل قسم أساسي (Bottom Sheet سلس)
  void _showAddSubCategoryModal(BuildContext context, String mainCategoryDocId) {
    final nameController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (contextModal, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        Expanded(
                          child: Text(
                              'إضافة فرعي لـ ($mainCategoryDocId)',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, color: appPrimaryColor, fontFamily: 'Cairo', fontSize: 16)
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black87, width: 1.2)),
                            child: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
                          ),
                        )
                      ],
                    ),
                    const Divider(height: 20),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(fontFamily: 'Cairo'),
                      decoration: InputDecoration(
                        labelText: 'اسم التصنيف الفرعي',
                        labelStyle: const TextStyle(fontFamily: 'Cairo'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: isSaving ? null : () async {
                        String newSub = nameController.text.trim();
                        if (newSub.isNotEmpty) {
                          setModalState(() => isSaving = true);
                          await _firestore.collection('categories').doc(mainCategoryDocId).update({
                            'subCategories': FieldValue.arrayUnion([newSub])
                          });

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        }
                      },
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('إضافة التصنيف الفرعي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 🗑️ حذف تصنيف فرعي
  void _deleteSubCategory(String mainCategoryDocId, String subCategory) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
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
        ),
      ),
    );
  }

  // 🗑️ حذف تصنيف أساسي بالكامل
  void _deleteMainCategory(String mainCategoryDocId) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: appBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
          ],
          title: const Text('إدارة الأقسام', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18, color: Colors.white)),
          centerTitle: true,
          backgroundColor: appPrimaryColor,
          elevation: 0,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddMainCategoryModal(context),
          backgroundColor: appSecondaryColor,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('تصنيف أساسي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ),
        body: Column(
          children: [
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
                    padding: const EdgeInsets.only(top: 16, right: 16, left: 16, bottom: 90),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final doc = categories[index];
                      final data = doc.data() as Map<String, dynamic>;

                      String mainCategoryName = data['name'] ?? doc.id;
                      List<dynamic> subCategoriesRaw = data['subCategories'] ?? [];
                      List<String> subCategories = List<String>.from(subCategoriesRaw);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        elevation: 1.5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: appPrimaryColor.withOpacity(0.05),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(Icons.category_rounded, color: appPrimaryColor, size: 22),
                                        const SizedBox(width: 10),
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
                                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                                    onPressed: () => _deleteMainCategory(doc.id),
                                    tooltip: 'حذف التصنيف الأساسي',
                                  )
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('التصنيفات الفرعية:', style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  // 👈 تصميم أنيق وواضح ومميز للكبسولات الفرعية
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: subCategories.map((sub) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: appSecondaryColor.withOpacity(0.5), width: 1.2),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(sub, style: TextStyle(fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: appPrimaryColor)),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () => _deleteSubCategory(doc.id, sub),
                                              child: Icon(Icons.cancel_rounded, size: 16, color: Colors.red.shade400),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => _showAddSubCategoryModal(context, doc.id),
                                      icon: Icon(Icons.add_circle_outline, color: appSecondaryColor, size: 18),
                                      label: Text('إضافة فرعي', style: TextStyle(color: appSecondaryColor, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        backgroundColor: appSecondaryColor.withOpacity(0.1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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