import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/invoice_model.dart'; // 👈 تأكد من مسار الـ Model اللي لسه عاملينه
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/invoice_cubit.dart';
class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  String invoiceType = 'sale'; // افتراضياً فاتورة مبيع
  String? selectedPartnerId;
  String? selectedPartnerName;
  List<InvoiceItemModel> selectedItems = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // حساب الإجمالي اللحظي
  double get invoiceTotal {
    return selectedItems.fold(0, (sum, item) => sum + item.totalItemPrice);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('إنشاء فاتورة جديدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. تحديد نوع الفاتورة (بيع / شراء)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTypeChip('فاتورة مبيعات', 'sale', Icons.arrow_upward, Colors.green),
                const SizedBox(width: 16),
                _buildTypeChip('فاتورة مشتريات', 'purchase', Icons.arrow_downward, Colors.orange),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. اختيار الطرف (العميل / المورد)
                  const Text('الطرف (العميل/المورد)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showPartnersBottomSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person, color: Colors.blue.shade900),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedPartnerName ?? 'اضغط لاختيار العميل أو المورد...',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: selectedPartnerName == null ? Colors.grey : Colors.black,
                                fontWeight: selectedPartnerName == null ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. قائمة المنتجات المضافة للفاتورة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المنتجات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton.icon(
                        onPressed: _showProductsBottomSheet,
                        icon: const Icon(Icons.add_circle),
                        label: const Text('إضافة منتج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (selectedItems.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.shopping_cart_checkout, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text('لم يتم إضافة أي منتجات للفاتورة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  else
                    ...selectedItems.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(item.productName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        subtitle: Text('${item.unitPrice} ج.م × ${item.quantity}', style: const TextStyle(fontFamily: 'Cairo')),
                        trailing: Text(
                          '${item.totalItemPrice} ج.م',
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                        leading: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              selectedItems.remove(item);
                            });
                          },
                        ),
                      ),
                    )),
                ],
              ),
            ),
          ),

          // 4. شريط الإجمالي والحفظ (Footer)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('إجمالي الفاتورة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 12)),
                        Text(
                          '$invoiceTotal ج.م',
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue.shade900),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      backgroundColor: Colors.blue.shade900,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saveInvoice,
                    child: const Text('حفظ واعتماد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ويدجت مساعدة لاختيار نوع الفاتورة
  Widget _buildTypeChip(String label, String value, IconData icon, Color activeColor) {
    final isSelected = invoiceType == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.black87),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ],
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) setState(() => invoiceType = value);
      },
      selectedColor: activeColor,
      backgroundColor: Colors.grey.shade200,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
    );
  }

  // 1️⃣ نافذة اختيار الأطراف (العملاء والموردين) السلسة
  void _showPartnersBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            children: [
              const Text('اختر الطرف', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('partners').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final partners = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: partners.length,
                      itemBuilder: (context, index) {
                        final data = partners[index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(data['name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          subtitle: Text(data['type'] == 'customer' ? 'عميل' : 'مورد', style: const TextStyle(fontFamily: 'Cairo')),
                          onTap: () {
                            setState(() {
                              selectedPartnerId = partners[index].id;
                              selectedPartnerName = data['name'];
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 2️⃣ نافذة اختيار المنتجات وتحديد الكمية السلسة
  void _showProductsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('اختر المنتج', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('products').where('isActive', isEqualTo: true).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final products = snapshot.data!.docs;
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final data = products[index].data() as Map<String, dynamic>;
                            final price = (data['price'] ?? 0.0).toDouble();
                            final stock = data['stock'] ?? data['stockQuantity'] ?? 0;

                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(data['imageUrl'] ?? '', width: 50, height: 50, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40)),
                              ),
                              title: Text(data['name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                              subtitle: Text('السعر: $price ج.م | المخزون: $stock', style: const TextStyle(fontFamily: 'Cairo')),
                              trailing: const Icon(Icons.add_circle, color: Colors.blue),
                              onTap: () {
                                Navigator.pop(context); // قفل قائمة المنتجات
                                _showQuantityDialog(products[index].id, data['name'], price); // فتح تحديد الكمية
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 3️⃣ تحديد الكمية للمنتج المختار
  void _showQuantityDialog(String productId, String productName, double price) {
    int quantity = 1;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('تحديد الكمية لـ $productName', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (quantity > 1) setDialogState(() => quantity--);
                      },
                      icon: const Icon(Icons.remove_circle, color: Colors.red, size: 32),
                    ),
                    Text('$quantity', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: () => setDialogState(() => quantity++),
                      icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                    onPressed: () {
                      setState(() {
                        selectedItems.add(InvoiceItemModel(
                          productId: productId,
                          productName: productName,
                          unitPrice: price, // 👈 تجميد السعر وقت الإضافة!
                          quantity: quantity,
                        ));
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('إضافة للفاتورة', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  // 4️⃣ دالة حفظ الفاتورة (مؤقتة لحين بناء الـ Logic الخاص بخصم المخزون)
  void _saveInvoice() {
    if (selectedPartnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار العميل/المورد', style: TextStyle(fontFamily: 'Cairo'))));
      return;
    }
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الفاتورة فارغة!', style: TextStyle(fontFamily: 'Cairo'))));
      return;
    }

    // تجهيز كائن الفاتورة
    final newInvoice = InvoiceModel(
      id: '', // هيتولد تلقائي في الـ Repo
      partnerId: selectedPartnerId!,
      partnerName: selectedPartnerName!,
      type: invoiceType,
      items: selectedItems,
      totalAmount: invoiceTotal,
      date: DateTime.now(),
      status: 'paid', // افتراضي مدفوعة (ممكن تتعدل لاحقاً للفواتير الآجلة)
    );

    // إرسال الفاتورة للـ Cubit لحفظها
    context.read<InvoiceCubit>().saveInvoice(newInvoice);
  }
}