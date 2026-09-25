import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';
import '../data/repos/admin_repo.dart';
// 👇 قم بتعديل هذا المسار حسب المكان الذي وضعت فيه ملف الخدمة
import '../../../features/admin/services/ai_image_service.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final AdminRepo adminRepo = AdminRepo();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🎨 ألوان الهوية
  final Color appPrimaryColor = const Color(0xFF0B1E3F);
  final Color appSecondaryColor = const Color(0xFFFF9F0A);

  String currentStatusFilter = 'all'; // all, active, archived
  String currentCategoryFilter = 'الكل';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 🖼️ نافذة تحديث صورة المنتج
  void _showImageUpdateOptions(BuildContext context, String docId, String productName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تعديل صورة:\n$productName', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: appPrimaryColor)),
            const Divider(thickness: 2, height: 30),

            // 🌟 خيار التوليد بالذكاء الاصطناعي
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.purple, size: 30),
              title: const Text('توليد بالذكاء الاصطناعي ✨', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(ctx); // إغلاق القائمة السفلية

                // إظهار شاشة تحميل للمستخدم لأن الذكاء الاصطناعي يستغرق 3-5 ثواني
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.purple),
                        SizedBox(height: 16),
                        Text('الذكاء الاصطناعي يقوم بتصوير المنتج... 📸✨\nيرجى الانتظار ثواني معدودة', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo')),
                      ],
                    ),
                  ),
                );

                try {
                  // استدعاء ملف الذكاء الاصطناعي
                  String permanentUrl = await AiImageService.generateAndUploadImage(productName);

                  // تحديث الرابط في فايربيز
                  await _firestore.collection('products').doc(docId).update({'imageUrl': permanentUrl});

                  if (mounted) {
                    Navigator.pop(context); // إغلاق شاشة التحميل
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصوير المنتج وحفظ الصورة بنجاح! 🎉', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // إغلاق شاشة التحميل
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('عذراً، فشل التوليد: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                  }
                }
              },
            ),

            ListTile(
              leading: Icon(Icons.camera_alt, color: appSecondaryColor, size: 30),
              title: const Text('التقاط بالكاميرا 📸', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('سيتم الربط بالكاميرا لاحقاً', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: appSecondaryColor));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue, size: 30),
              title: const Text('اختيار من المعرض 🖼️', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم الربط بالمعرض لاحقاً', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.blue));
              },
            ),
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
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('إدارة المخزون والمنتجات', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
          backgroundColor: appPrimaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: Column(
          children: [
            // 🔍 1. شريط البحث الذكي
            Container(
              color: appPrimaryColor,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                style: const TextStyle(fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم المنتج سريعاً...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => searchQuery = '');
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),

            // 🎛️ 2. فلاتر الحالة والأقسام
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildStatusChip('الكل', 'all', Icons.all_inclusive),
                        const SizedBox(width: 8),
                        _buildStatusChip('متاح بالمخزن', 'active', Icons.check_circle_outline),
                        const SizedBox(width: 8),
                        _buildStatusChip('مسودات (مخفي)', 'archived', Icons.archive_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('categories').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox(height: 35);
                      final categories = ['الكل', ...snapshot.data!.docs.map((e) => e.id)];

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: categories.map((cat) {
                            final isSelected = currentCategoryFilter == cat;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: ChoiceChip(
                                label: Text(cat, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                                selected: isSelected,
                                onSelected: (_) => setState(() => currentCategoryFilter = cat),
                                selectedColor: appSecondaryColor.withValues(alpha: 0.2),
                                backgroundColor: Colors.grey.shade100,
                                labelStyle: TextStyle(
                                  color: isSelected ? appSecondaryColor : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                side: BorderSide(color: isSelected ? appSecondaryColor : Colors.transparent),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // 📋 3. قائمة المنتجات
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('products').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: appSecondaryColor));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

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

                  filteredDocs.sort((a, b) {
                    Timestamp tA = (a.data() as Map<String, dynamic>)['createdAt'] ?? Timestamp.now();
                    Timestamp tB = (b.data() as Map<String, dynamic>)['createdAt'] ?? Timestamp.now();
                    return tB.compareTo(tA);
                  });

                  if (filteredDocs.isEmpty) return _buildEmptyState();

                  return ListView.builder(
                    // 👇 التعديل الأهم: مساحة سفلية (90) لرفع الكارت الأخير فوق الزر
                    padding: const EdgeInsets.only(top: 12, right: 12, left: 12, bottom: 90),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final bool isActive = data['isActive'] ?? true;
                      final String imageUrl = data['imageUrl'] ?? '';
                      final String name = data['name'] ?? 'بدون اسم';
                      final String category = data['category'] ?? 'عام';
                      final price = data['price'] ?? 0.0;
                      final int stock = data['stockQuantity'] ?? 0;

                      return Card(
                        color: isActive ? Colors.white : const Color(0xFFFFFDF5),
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: isActive ? 1 : 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isActive ? Colors.grey.shade200 : Colors.orange.withValues(alpha: 0.3))
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _showImageUpdateOptions(context, doc.id, name),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      width: 65,
                                      height: 65,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey))
                                            : const Center(child: Icon(Icons.add_a_photo, color: Colors.grey, size: 24)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(color: appSecondaryColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                                      child: const Icon(Icons.edit, size: 10, color: Colors.white),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo', color: isActive ? Colors.black87 : Colors.grey.shade700, height: 1.2),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!isActive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            margin: const EdgeInsets.only(right: 6),
                                            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                            child: const Text('مسودة', style: TextStyle(fontSize: 9, color: Colors.deepOrange, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(category, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'Cairo')),
                                    const SizedBox(height: 6),

                                    Row(
                                      children: [
                                        Text('$price ج.م', style: TextStyle(color: appSecondaryColor, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                                        const Spacer(),
                                        Text('رصيد: $stock', style: TextStyle(color: stock > 0 ? Colors.green.shade700 : Colors.red, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Cairo')),
                                        const SizedBox(width: 12),

                                        _buildCompactActionBtn(Icons.add_box, Colors.teal, 'دفعة', isActive ? () => _showAddBatchModal(context, doc.id, name) : null),
                                        const SizedBox(width: 6),
                                        _buildCompactActionBtn(Icons.edit_note, Colors.blue, 'السعر', isActive ? () => _showEditPriceDialog(context, doc.id, price.toString()) : null),
                                        const SizedBox(width: 6),
                                        _buildCompactActionBtn(isActive ? Icons.visibility_off : Icons.visibility, isActive ? Colors.red : Colors.green, isActive ? 'إخفاء' : 'نشر', () {
                                          _firestore.collection('products').doc(doc.id).update({'isActive': !isActive});
                                        }),
                                      ],
                                    ),
                                  ],
                                ),
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

        // 👇 نقل الزر لليمين مع عدم تكراره
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(Routes.addProduct),
          backgroundColor: appPrimaryColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('إضافة منتج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String filterValue, IconData icon) {
    final isSelected = currentStatusFilter == filterValue;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.black87),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => currentStatusFilter = filterValue),
      selectedColor: appPrimaryColor,
      backgroundColor: Colors.grey.shade200,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildCompactActionBtn(IconData icon, Color color, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: onTap == null ? Colors.grey.shade200 : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: onTap == null ? Colors.transparent : color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 16, color: onTap == null ? Colors.grey : color),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('لا توجد منتجات مطابقة للبحث أو الفلتر', style: TextStyle(fontSize: 15, color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAddBatchModal(BuildContext context, String docId, String productName) {
    final TextEditingController qtyController = TextEditingController();
    final TextEditingController costController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('إضافة كمية لـ $productName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 20),
                TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الكمية الجديدة المستلمة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.inventory_2_outlined))),
                const SizedBox(height: 16),
                TextField(controller: costController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'سعر التكلفة (الشراء) للقطعة الواحدة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.price_change_outlined))),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    final int qty = int.tryParse(qtyController.text.trim()) ?? 0;
                    final double cost = double.tryParse(costController.text.trim()) ?? 0.0;
                    if (qty <= 0 || cost <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال كمية وسعر تكلفة صحيحين', style: TextStyle(fontFamily: 'Cairo'))));
                      return;
                    }
                    final newBatch = {'batchId': DateTime.now().millisecondsSinceEpoch.toString(), 'quantity': qty, 'costPrice': cost, 'dateAdded': Timestamp.now()};
                    await _firestore.collection('products').doc(docId).update({'batches': FieldValue.arrayUnion([newBatch]), 'stockQuantity': FieldValue.increment(qty)});
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة الشحنة بنجاح!', style: TextStyle(fontFamily: 'Cairo'))));
                    }
                  },
                  child: const Text('حفظ الشحنة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditPriceDialog(BuildContext context, String docId, String currentPrice) {
    final controller = TextEditingController(text: currentPrice);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل سعر البيع', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع الجديد للعميل', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appSecondaryColor),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                adminRepo.updateProductPrice(docId, double.parse(controller.text));
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}