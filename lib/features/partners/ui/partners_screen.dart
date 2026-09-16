import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// تأكد من تعديل هذا المسار حسب مكان ملف الـ Models في مشروعك
import '../../../core/models/erp_models.dart';

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({Key? key}) : super(key: key);

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // دالة لفتح نافذة الإضافة (Modal Bottom Sheet) - بدون أي Dropdowns
  void _showAddPartnerModal(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    String selectedType = 'customer';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              // 👈 الحل هنا: تغليف المحتوى بـ SingleChildScrollView لمنع الأوفر فلو عند فتح الكيبورد
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'إضافة طرف جديد',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'اسم العميل / المورد',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('حدد نوع الطرف:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildChoiceChip('customer', 'عميل', selectedType, (val) {
                          setModalState(() { selectedType = val; });
                        }),
                        _buildChoiceChip('supplier', 'مورد', selectedType, (val) {
                          setModalState(() { selectedType = val; });
                        }),
                        _buildChoiceChip('partner', 'شريك', selectedType, (val) {
                          setModalState(() { selectedType = val; });
                        }),
                        _buildChoiceChip('shipping', 'شركة شحن', selectedType, (val) {
                          setModalState(() { selectedType = val; });
                        }),
                      ],
                    ),
                    const SizedBox(height: 30),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.blue.shade900,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;

                        final newPartner = PartnerModel(
                          id: '',
                          name: nameController.text.trim(),
                          type: selectedType,
                          phone: phoneController.text.trim(),
                        );

                        await _firestore.collection('partners').add(newPartner.toMap());

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم إضافة الطرف بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                          );
                        }
                      },
                      child: const Text('حفظ البيانات', style: TextStyle(fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // تصميم شريحة الاختيار
  Widget _buildChoiceChip(String value, String label, String groupValue, Function(String) onSelected) {
    final isSelected = value == groupValue;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontFamily: 'Cairo', color: isSelected ? Colors.white : Colors.black)),
      selected: isSelected,
      selectedColor: Colors.blue.shade700,
      onSelected: (_) => onSelected(value),
    );
  }

  // دالة لترجمة النوع في واجهة العرض
  String _translateType(String type) {
    switch (type) {
      case 'customer': return 'عميل';
      case 'supplier': return 'مورد';
      case 'partner': return 'شريك';
      case 'shipping': return 'شركة شحن';
      default: return 'غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأطراف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('partners').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ في جلب البيانات: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('لا يوجد عملاء أو موردين حتى الآن.\nاضغط على + للإضافة.',
                  textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontSize: 16)),
            );
          }

          final partners = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: partners.length,
            itemBuilder: (context, index) {
              final doc = partners[index];
              // تحويل البيانات من فايربيز إلى الموديل الخاص بنا
              final partner = PartnerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(
                      partner.type == 'customer' ? Icons.person :
                      partner.type == 'supplier' ? Icons.store :
                      partner.type == 'shipping' ? Icons.local_shipping : Icons.handshake,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  title: Text(partner.name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  subtitle: Text(partner.phone, style: const TextStyle(fontFamily: 'Cairo')),
                  trailing: Chip(
                    label: Text(_translateType(partner.type), style: const TextStyle(fontSize: 12, fontFamily: 'Cairo')),
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPartnerModal(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ),
    );
  }
}