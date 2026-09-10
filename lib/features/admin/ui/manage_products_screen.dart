import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/repos/admin_repo.dart';

class ManageProductsScreen extends StatefulWidget {
  ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final AdminRepo adminRepo = AdminRepo();

  // 👈 متغير للتحكم في الفلتر الحالي (الكل - متاح - أرشيف)
  String currentFilter = 'all';

  // 👈 دالة ذكية لتحديد نوع الاستعلام (Query) بناءً على الفلتر المختار
  Stream<QuerySnapshot> _getProductsStream() {
    final collection = FirebaseFirestore.instance.collection('products');

    if (currentFilter == 'active') {
      return collection.where('isActive', isEqualTo: true).snapshots();
    } else if (currentFilter == 'archived') {
      return collection.where('isActive', isEqualTo: false).snapshots();
    }
    // 'all'
    return collection.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('إدارة المنتجات', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 🗂️ 1. شريط الأرشفة الذكية (الفلاتر)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFilterChip('الكل', 'all', Icons.all_inclusive),
                _buildFilterChip('المتاح فقط', 'active', Icons.check_circle_outline),
                _buildFilterChip('الأرشيف (مخفي)', 'archived', Icons.archive_outlined),
              ],
            ),
          ),

          // 📦 2. قائمة المنتجات
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getProductsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('لا توجد منتجات مطابقة للفلتر', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final products = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final doc = products[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final bool isActive = data['isActive'] ?? true;

                    return Card(
                      color: isActive ? Colors.white : Colors.grey.shade200,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: isActive ? 1.0 : 0.4,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(data['imageUrl'], width: 60, height: 60, fit: BoxFit.cover),
                              ),
                            ),
                            if (!isActive)
                              const Icon(Icons.block, color: Colors.red, size: 30),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                  color: isActive ? Colors.black : Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isActive)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8)
                                ),
                                child: const Text('مخفي', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        subtitle: Text(
                            '${data['price']} ج.م',
                            style: TextStyle(
                                color: isActive ? const Color(0xFF007BFF) : Colors.grey.shade600,
                                fontWeight: FontWeight.bold
                            )
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: isActive ? Colors.green : Colors.grey),
                              onPressed: isActive ? () => _showEditPriceDialog(context, doc.id, data['price'].toString()) : null,
                            ),
                            IconButton(
                              icon: Icon(
                                  isActive ? Icons.visibility_off : Icons.visibility,
                                  color: isActive ? Colors.red : Colors.blue
                              ),
                              tooltip: isActive ? 'إخفاء المنتج' : 'إعادة النشر',
                              onPressed: () {
                                FirebaseFirestore.instance.collection('products').doc(doc.id).update({
                                  'isActive': !isActive,
                                });
                              },
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
    );
  }

  // 🎛️ أداة مساعدة لرسم زراير الفلتر بشكل أنيق
  Widget _buildFilterChip(String label, String filterValue, IconData icon) {
    final isSelected = currentFilter == filterValue;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.black87),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          currentFilter = filterValue;
        });
      },
      selectedColor: const Color(0xFF000826),
      backgroundColor: Colors.grey.shade200,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _showEditPriceDialog(BuildContext context, String docId, String currentPrice) {
    final controller = TextEditingController(text: currentPrice);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل السعر', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'السعر الجديد', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF)),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                adminRepo.updateProductPrice(docId, double.parse(controller.text));
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}