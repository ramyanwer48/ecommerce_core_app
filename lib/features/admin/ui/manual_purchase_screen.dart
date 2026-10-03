import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../purchases/services/purchase_service.dart';

class ManualPurchaseScreen extends StatefulWidget {
  const ManualPurchaseScreen({super.key});

  @override
  State<ManualPurchaseScreen> createState() => _ManualPurchaseScreenState();
}

class _ManualPurchaseScreenState extends State<ManualPurchaseScreen> {
  // 👈 1. استبدال نظام الاختيار المعقد بـ Controller عادي لكتابة اسم المورد
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _invoiceNumberController = TextEditingController();
  late TextEditingController _dateController;
  late DateTime _selectedDate;

  final List<Map<String, dynamic>> _invoiceItems = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateController = TextEditingController(
      text: "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
    );
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceNumberController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    return _invoiceItems.fold(0.0, (sum, item) {
      double price = (item['price'] as double);
      int qty = (item['qty'] as int);
      return sum + (price * qty);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D1B2A),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _showAddProductSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    String? selectedProductId;
    String? selectedProductName;
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final sellingPriceController = TextEditingController();
    final conversionFactorController = TextEditingController(text: '1');
    String selectedCategory = 'General';
    String selectedSubCategory = 'General';
    bool isNewProduct = true;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setSheetState) {
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('إضافة منتج للفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (context) => Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance.collection('products').snapshots(),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                              var products = snapshot.data!.docs;
                                              return ListView.builder(
                                                itemCount: products.length,
                                                itemBuilder: (context, index) {
                                                  final data = products[index].data() as Map<String, dynamic>;
                                                  return ListTile(
                                                    leading: const Icon(Icons.inventory_2_outlined, color: Colors.indigo),
                                                    title: Text(data['name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                                    onTap: () {
                                                      setSheetState(() {
                                                        selectedProductId = products[index].id;
                                                        selectedProductName = data['name'];
                                                        priceController.text = (data['costPrice'] ?? 0).toString();
                                                        sellingPriceController.text = (data['price'] ?? 0).toString();
                                                        selectedCategory = data['category'] ?? 'General';
                                                        selectedSubCategory = data['subCategory'] ?? 'General';
                                                        isNewProduct = false;
                                                      });
                                                      context.pop();
                                                    },
                                                  );
                                                },
                                              );
                                            }
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(selectedProductName ?? 'اختر منتجاً موجوداً', style: TextStyle(fontFamily: 'Cairo', color: selectedProductName == null ? Colors.grey.shade600 : Colors.black, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                        const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.indigo),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(labelText: 'أو اكتب منتج جديد', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    onChanged: (val) {
                                      if(val.isNotEmpty){
                                        setSheetState((){
                                          selectedProductName = val;
                                          selectedProductId = null;
                                          isNewProduct = true;
                                        });
                                      }
                                    },
                                  )
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(child: TextField(controller: quantityController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الكمية الواردة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: conversionFactorController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الكرتونة (كام قطعة؟)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), hintText: 'مثال: 12'))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'سعر الشراء (للكل)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: sellingPriceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'سعر البيع المقترح', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                            ],
                          ),
                          const SizedBox(height: 24),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () {
                              if (selectedProductName == null || quantityController.text.isEmpty || priceController.text.isEmpty) return;
                              FocusManager.instance.primaryFocus?.unfocus();
                              setState(() {
                                _invoiceItems.add({
                                  'mappedName': selectedProductName,
                                  'rawAiName': selectedProductName,
                                  'mappedId': selectedProductId,
                                  'isNewProduct': isNewProduct,
                                  'qty': int.parse(quantityController.text),
                                  'price': double.parse(priceController.text),
                                  'conversionFactor': int.parse(conversionFactorController.text),
                                  'sellingPrice': sellingPriceController.text.isNotEmpty ? double.parse(sellingPriceController.text) : (double.parse(priceController.text) * 1.25),
                                  'mainCategory': selectedCategory,
                                  'subCategory': selectedSubCategory,
                                  'imageUrls': <String>[],
                                });
                              });
                              context.pop();
                            },
                            child: const Text('إضافة للفاتورة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  Future<void> _saveInvoice() async {
    if (_supplierController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إدخال اسم المورد!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      return;
    }
    if (_invoiceNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إدخال رقم الفاتورة!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      return;
    }
    if (_invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الفاتورة فارغة، أضف منتجات!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);

    try {
      final purchaseService = PurchaseService();
      await purchaseService.processApprovedInvoice(
        supplierName: _supplierController.text.trim(), // 👈 أخذ اسم المورد من الحقل مباشرة
        invoiceNumber: _invoiceNumberController.text.trim(),
        invoiceDate: _selectedDate,
        items: _invoiceItems,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترحيل الفاتورة وتحديث سجل المشتريات بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF0D1B2A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text('فاتورة مشتريات (يدوي)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            centerTitle: true,
            backgroundColor: primaryNavy,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _isSaving
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // 👈 2. مربع كتابة المورد زي الـ AI بالظبط
                TextField(
                  controller: _supplierController,
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'اسم المورد',
                    labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Icons.store, color: Colors.indigo),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // 👈 3. مستطيلات الرقم والتاريخ براحتها خالص
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _invoiceNumberController,
                        keyboardType: TextInputType.text,
                        maxLines: 2,
                        minLines: 1,
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'رقم الفاتورة (مطلوب)',
                          labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true, fillColor: Colors.white,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'تاريخ الفاتورة',
                          labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true, fillColor: Colors.white,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('البضاعة الواردة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                    ElevatedButton.icon(
                      onPressed: _showAddProductSheet,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة منتج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _invoiceItems.isEmpty
                    ? Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: const Center(child: Text('لم يتم إضافة أي منتجات للفاتورة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _invoiceItems.length,
                  itemBuilder: (context, index) {
                    final item = _invoiceItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.inventory, color: Colors.white, size: 18)),
                        title: Text(item['mappedName'], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('الكمية: ${item['qty']} x ${item['conversionFactor']}  |  إجمالي السعر: ${item['price']} ج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { FocusManager.instance.primaryFocus?.unfocus(); setState(() => _invoiceItems.removeAt(index)); }),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.indigo.shade100)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إجمالي الفاتورة:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${_totalAmount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 20, color: Colors.indigo)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveInvoice,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('حفظ الفاتورة واعتماد المخزون', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}