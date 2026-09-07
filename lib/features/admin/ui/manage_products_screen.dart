import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/repos/admin_repo.dart';

class ManageProductsScreen extends StatelessWidget {
  final AdminRepo adminRepo = AdminRepo();

  ManageProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('إدارة المنتجات', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF000826),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد منتجات حالياً', style: TextStyle(fontSize: 18)));
          }

          final products = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final doc = products[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(data['imageUrl'], width: 60, height: 60, fit: BoxFit.cover),
                  ),
                  title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${data['price']} ج.م', style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // زر تعديل السعر
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.green),
                        onPressed: () => _showEditPriceDialog(context, doc.id, data['price'].toString()),
                      ),
                      // زر الحذف
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => adminRepo.deleteProduct(doc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // نافذة منبثقة لتعديل السعر
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