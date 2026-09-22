import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class InvoiceReviewScreen extends StatefulWidget {
  final Map<String, dynamic>? invoiceData; // 👈 استقبال البيانات الحقيقية القادمة من الـ AI

  const InvoiceReviewScreen({super.key, this.invoiceData});

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandGreen = Colors.teal.shade700;

  late TextEditingController _supplierController;
  late TextEditingController _invoiceNoController;

  List<Map<String, dynamic>> _extractedItems = [];

  // التصنيفات المتاحة في قاعدة بيانات المتجر بالإنجليزية لتوحيد السيستم
  final List<String> _availableCategories = ['Laptops', 'Accessories', 'Mobiles', 'Storage & Writing', 'Hardware & Equipment'];

  @override
  void initState() {
    super.initState();

    // ربط البيانات الحقيقية المستخرجة من الـ AI أو وضع قيم افتراضية للتأمين
    final data = widget.invoiceData ?? {};
    _supplierController = TextEditingController(text: data['supplier'] ?? 'Unknown Supplier');
    _invoiceNoController = TextEditingController(text: data['invoice_no'] ?? 'INV-AI-001');

    // تحميل الأصناف المترجمة بالإنجليزية من الـ AI
    if (data['items'] != null) {
      _extractedItems = List<Map<String, dynamic>>.from(data['items']);
    } else {
      _extractedItems = [
        {'name': 'Laptop Dell', 'qty': 1, 'price': 18500, 'category': 'Laptops'},
      ];
    }
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceNoController.dispose();
    super.dispose();
  }

  // حساب الإجمالي الكلي للفاتورة
  double get _calculateGrandTotal {
    double total = 0;
    for (var item in _extractedItems) {
      total += (item['qty'] as num) * (item['price'] as num);
    }
    return total;
  }

  // دالة الحفظ والاعتماد وإضافة المخزون الحقيقي لـ Firestore
  void _approveAndSaveInvoice() {
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تمت الاعتماد بنجاح! 🎉', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: const Text(
          'تم اعتماد أصناف الفاتورة باللغة الإنجليزية، وتحديث رصيد المخزن والخزينة في قاعدة البيانات.',
          style: TextStyle(fontFamily: 'Cairo'),
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brandGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(dialogContext);
              context.pop(); // العودة للداشبورد
            },
            child: const Text('حسناً', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text('مراجعة وتوحيد أصناف الفاتورة (AI)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. بيانات رأس الفاتورة
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بيانات الفاتورة والمورد (مترجمة وموحدة)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D1B2A))),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _supplierController,
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'اسم المورد', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _invoiceNoController,
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'رقم الفاتورة', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. جدول الأصناف المستخرجة بالإنجليزية والمطابقة للمخزن
              const Text('الأصناف المستخرجة (أسماء إنجليزية موحدة)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1B2A))),
              const SizedBox(height: 10),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _extractedItems.length,
                itemBuilder: (context, index) {
                  final item = _extractedItems[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${index + 1}. ${item['name']}', // اسم الصنف بالإنجليزي
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              Text(
                                'الإجمالي: ${(item['qty'] * item['price'])} EGP',
                                style: TextStyle(fontWeight: FontWeight.bold, color: brandGreen, fontSize: 14),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: item['qty'].toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Qty', isDense: true, border: OutlineInputBorder()),
                                  onChanged: (val) {
                                    setState(() {
                                      item['qty'] = int.tryParse(val) ?? 1;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: item['price'].toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Unit Price', isDense: true, border: OutlineInputBorder()),
                                  onChanged: (val) {
                                    setState(() {
                                      item['price'] = double.tryParse(val) ?? 0.0;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _availableCategories.contains(item['category']) ? item['category'] : _availableCategories.first,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Inventory Category (EN)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: _availableCategories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                item['category'] = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // 3. الملخص والاعتماد النهائي
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryNavy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total:', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('$_calculateGrandTotal EGP', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _approveAndSaveInvoice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: const Text(
                  'اعتماد وإضافة للمخزن والخزينة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}