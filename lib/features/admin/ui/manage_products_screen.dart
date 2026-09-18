import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';
import '../data/repos/admin_repo.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final AdminRepo adminRepo = AdminRepo();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String currentFilter = 'all';

  Stream<QuerySnapshot> _getProductsStream() {
    final collection = _firestore.collection('products');
    if (currentFilter == 'active') {
      return collection.where('isActive', isEqualTo: true).snapshots();
    } else if (currentFilter == 'archived') {
      return collection.where('isActive', isEqualTo: false).snapshots();
    }
    return collection.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('إدارة المنتجات والمخزون', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
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
                        const Text('لا توجد منتجات مطابقة للفلتر', style: TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'Cairo')),
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
                    final String imageUrl = data['imageUrl'] ?? data['image'] ?? '';
                    final String name = data['name'] ?? data['title'] ?? 'بدون اسم';
                    final price = data['price'] ?? data['currentSalePrice'] ?? 0.0;

                    // 👈 قراءة المخزون من stockQuantity كأولوية قصوى
                    final int stock = data['stockQuantity'] ?? data['quantity'] ?? 0;

                    return Card(
                      color: isActive ? Colors.white : Colors.grey.shade200,
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: isActive ? 1.0 : 0.4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image, size: 40, color: Colors.grey))
                                      : const Icon(Icons.image, size: 40, color: Colors.grey),
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
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                    decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                    color: isActive ? Colors.black : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '$price ج.م',
                                    style: TextStyle(
                                        color: isActive ? const Color(0xFF007BFF) : Colors.grey.shade600,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Cairo'
                                    )
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'المتوفر في المخزن: $stock',
                                  style: TextStyle(
                                    color: stock > 0 ? Colors.green.shade700 : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🌟 زر إضافة دفعة جديدة (سعر التكلفة)
                                IconButton(
                                  icon: Icon(Icons.add_box_rounded, color: isActive ? Colors.orange.shade600 : Colors.grey, size: 28),
                                  tooltip: 'إضافة شحنة/كمية جديدة',
                                  onPressed: isActive ? () => _showAddBatchModal(context, doc.id, name) : null,
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit, color: isActive ? Colors.green : Colors.grey, size: 26),
                                  tooltip: 'تعديل السعر الأساسي',
                                  onPressed: isActive ? () => _showEditPriceDialog(context, doc.id, price.toString()) : null,
                                ),
                                IconButton(
                                  icon: Icon(
                                      isActive ? Icons.visibility_off : Icons.visibility,
                                      color: isActive ? Colors.red : Colors.blue,
                                      size: 26
                                  ),
                                  tooltip: isActive ? 'إخفاء المنتج' : 'إعادة النشر',
                                  onPressed: () {
                                    _firestore.collection('products').doc(doc.id).update({
                                      'isActive': !isActive,
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.addProduct),
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('إضافة منتج جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterValue, IconData icon) {
    final isSelected = currentFilter == filterValue;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.black87),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontFamily: 'Cairo')),
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

  // 📦 نافذة إضافة شحنة/كمية جديدة (سعر التكلفة)
  void _showAddBatchModal(BuildContext context, String docId, String productName) {
    final TextEditingController qtyController = TextEditingController();
    final TextEditingController costController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'إضافة كمية لـ $productName',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'الكمية الجديدة المستلمة',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'سعر التكلفة (الشراء) للقطعة الواحدة', // 👈 توضيح أنه سعر التكلفة
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.price_change_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final int qty = int.tryParse(qtyController.text.trim()) ?? 0;
                    final double cost = double.tryParse(costController.text.trim()) ?? 0.0;

                    if (qty <= 0 || cost <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال كمية وسعر تكلفة صحيحين', style: TextStyle(fontFamily: 'Cairo'))));
                      return;
                    }

                    final newBatch = {
                      'batchId': DateTime.now().millisecondsSinceEpoch.toString(),
                      'quantity': qty,
                      'costPrice': cost, // 👈 تخزين سعر التكلفة
                      'dateAdded': Timestamp.now(),
                    };

                    // 👇 تم إزالة حقل 'stock' القديم من هنا
                    await _firestore.collection('products').doc(docId).update({
                      'batches': FieldValue.arrayUnion([newBatch]),
                      'stockQuantity': FieldValue.increment(qty),
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إضافة الشحنة بنجاح!', style: TextStyle(fontFamily: 'Cairo'))),
                      );
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
        title: const Text('تعديل السعر الأساسي', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'السعر الجديد للعميل', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF)),
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