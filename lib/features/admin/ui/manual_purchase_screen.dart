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
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _invoiceNumberController = TextEditingController();
  late TextEditingController _dateController;
  late DateTime _selectedDate;

  final List<Map<String, dynamic>> _invoiceItems = [];
  bool _isSaving = false;

  // 🚀 الألوان الثابتة للهوية
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;
  final Color bgSoftColor = const Color(0xFFF4F7FB);

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
            colorScheme: ColorScheme.light(
              primary: primaryNavy,
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

  // 🚀 نافذة اختيار الأقسام (عشان لو المنتج جديد)
  void _showCategorySheet(String title, List<String> items, String? selectedItem, Function(String) onSelect) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 40),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 28), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = item == selectedItem;
                    return ListTile(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelect(item);
                        Navigator.pop(ctx);
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: isSelected ? brandOrange.withOpacity(0.1) : Colors.transparent,
                      title: Text(item, style: TextStyle(fontFamily: 'Cairo', fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? brandOrange : Colors.black87)),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: brandOrange) : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 الترتيب الجديد الصاروخي والمنطقي جداً لنافذة إضافة المنتج
  void _showAddProductSheet() {
    FocusManager.instance.primaryFocus?.unfocus();

    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final sellingPriceController = TextEditingController();
    final conversionFactorController = TextEditingController(text: '1');

    String? selectedProductId;
    bool isNewProduct = true;

    String selectedCategory = 'الكل';
    String selectedSubCategory = 'الكل';
    List<String> currentSubCategories = [];

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setSheetState) {
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: GestureDetector(
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const SizedBox(width: 40),
                                  Text('إضافة صنف للفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 1️⃣ زرار اختيار منتج مسجل (عشان يسهل على المستخدم)
                              OutlinedButton.icon(
                                onPressed: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                                    builder: (ctx) => Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance.collection('products').snapshots(),
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                            var products = snapshot.data!.docs;
                                            if (products.isEmpty) {
                                              return const Center(child: Text('لا توجد منتجات مسجلة، أدخل منتج جديد.', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)));
                                            }
                                            return ListView.builder(
                                              itemCount: products.length,
                                              itemBuilder: (context, index) {
                                                final data = products[index].data() as Map<String, dynamic>;
                                                return ListTile(
                                                  leading: Icon(Icons.inventory_2_outlined, color: brandOrange),
                                                  title: Text(data['name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                                  onTap: () {
                                                    setSheetState(() {
                                                      selectedProductId = products[index].id;
                                                      nameController.text = data['name'];
                                                      priceController.text = (data['costPrice'] ?? 0).toString();
                                                      sellingPriceController.text = (data['price'] ?? 0).toString();
                                                      selectedCategory = data['category'] ?? 'الكل';
                                                      selectedSubCategory = data['subCategory'] ?? 'الكل';
                                                      isNewProduct = false; // منتج موجود بالفعل
                                                    });
                                                    Navigator.pop(ctx);
                                                  },
                                                );
                                              },
                                            );
                                          }
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: primaryNavy, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: Icon(Icons.search_rounded, color: primaryNavy),
                                label: Text('اختر من المنتجات المسجلة مسبقاً', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 14)),
                              ),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  children: [
                                    Expanded(child: Divider()),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text('أو', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold)),
                                    ),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                              ),

                              // 2️⃣ حقل كتابة اسم المنتج (واضح وصريح)
                              TextFormField(
                                controller: nameController,
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: 'اسم المنتج (جديد أو مسجل)',
                                  labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                                  filled: true, fillColor: bgSoftColor,
                                  prefixIcon: Icon(Icons.edit_note_rounded, color: brandOrange),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                onChanged: (val) {
                                  // لو غير الاسم بإيده، نعتبره منتج جديد عشان يسجل أقسامه
                                  setSheetState(() {
                                    isNewProduct = true;
                                    selectedProductId = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              // 3️⃣ الأقسام (تظهر فقط لو المنتج جديد مش متسجل قبل كده)
                              if (isNewProduct) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: brandOrange.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: brandOrange.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('تصنيف المنتج الجديد:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: primaryNavy)),
                                      const SizedBox(height: 12),
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) return const SizedBox.shrink();
                                          final docs = snapshot.data!.docs;
                                          List<String> mainCategories = docs.map((doc) => doc.id).toList();

                                          return Column(
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  _showCategorySheet('القسم الأساسي', mainCategories, selectedCategory, (val) {
                                                    setSheetState(() {
                                                      selectedCategory = val;
                                                      selectedSubCategory = 'الكل';
                                                      final docData = docs.firstWhere((d) => d.id == val).data() as Map<String, dynamic>;
                                                      currentSubCategories = List<String>.from(docData['subCategories'] ?? []);
                                                    });
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(child: Text(selectedCategory, style: TextStyle(fontFamily: 'Cairo', color: primaryNavy, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                                      Icon(Icons.keyboard_arrow_down, color: primaryNavy),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (currentSubCategories.isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                InkWell(
                                                  onTap: () {
                                                    _showCategorySheet('القسم الفرعي', currentSubCategories, selectedSubCategory, (val) {
                                                      setSheetState(() => selectedSubCategory = val);
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(child: Text(selectedSubCategory, style: TextStyle(fontFamily: 'Cairo', color: primaryNavy, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                                        Icon(Icons.keyboard_arrow_down, color: primaryNavy),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // 4️⃣ الكميات والأسعار (مرتبة بشكل مريح للعين)
                              Row(
                                children: [
                                  Expanded(child: TextFormField(controller: quantityController, keyboardType: TextInputType.number, textInputAction: TextInputAction.next, style: const TextStyle(fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'الكمية الواردة', labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13), filled: true, fillColor: bgSoftColor, prefixIcon: const Icon(Icons.add_shopping_cart, color: Colors.teal), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                                  const SizedBox(width: 8),
                                  Expanded(child: TextFormField(controller: conversionFactorController, keyboardType: TextInputType.number, textInputAction: TextInputAction.next, style: const TextStyle(fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'الكرتونة (كم قطعة؟)', labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13), filled: true, fillColor: bgSoftColor, prefixIcon: const Icon(Icons.layers_rounded, color: Colors.blueAccent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: TextFormField(controller: priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next, style: const TextStyle(fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'سعر شراء القطعة', labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13), filled: true, fillColor: bgSoftColor, prefixIcon: const Icon(Icons.attach_money, color: Colors.redAccent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                                  const SizedBox(width: 8),
                                  Expanded(child: TextFormField(controller: sellingPriceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.done, style: const TextStyle(fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'سعر البيع للعميل', labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13), filled: true, fillColor: bgSoftColor, prefixIcon: Icon(Icons.sell_rounded, color: brandOrange), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // 5️⃣ زرار الحفظ
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                                onPressed: () {
                                  if (nameController.text.trim().isEmpty || quantityController.text.isEmpty || priceController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برجاء إدخال اسم المنتج والكمية والسعر!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
                                    return;
                                  }
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  setState(() {
                                    _invoiceItems.add({
                                      'mappedName': nameController.text.trim(),
                                      'rawAiName': nameController.text.trim(),
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
                                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                                label: const Text('اعتماد المنتج في الفاتورة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ],
                          ),
                        ),
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
        supplierName: _supplierController.text.trim(),
        invoiceNumber: _invoiceNumberController.text.trim(),
        invoiceDate: _selectedDate,
        items: _invoiceItems,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترحيل الفاتورة وتحديث المخزون بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: bgSoftColor,
          appBar: AppBar(
            title: const Text('فاتورة مشتريات (يدوي)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            centerTitle: true,
            backgroundColor: primaryNavy,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: _isSaving
              ? Center(child: CircularProgressIndicator(color: brandOrange))
              : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🚀 بيانات الفاتورة الأساسية
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بيانات الفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _supplierController,
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'اسم المورد / الشركة',
                          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'),
                          prefixIcon: Icon(Icons.store_rounded, color: primaryNavy),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true, fillColor: bgSoftColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 🚀 فصلنا رقم الفاتورة والتاريخ عشان ياخدوا راحتهم وميتقصش منهم حاجة
                      TextFormField(
                        controller: _invoiceNumberController,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'رقم الفاتورة (مطلوب)',
                          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'),
                          prefixIcon: const Icon(Icons.numbers_rounded, color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true, fillColor: bgSoftColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'تاريخ الفاتورة',
                          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'),
                          prefixIcon: Icon(Icons.calendar_month_rounded, color: brandOrange),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true, fillColor: bgSoftColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 🚀 الأصناف
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الأصناف (${_invoiceItems.length})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
                    ElevatedButton.icon(
                      onPressed: _showAddProductSheet,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: brandOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _invoiceItems.isEmpty
                    ? Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.post_add_rounded, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('الفاتورة فارغة.. أضف منتجات', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _invoiceItems.length,
                  itemBuilder: (context, index) {
                    final item = _invoiceItems[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: bgSoftColor, shape: BoxShape.circle),
                          child: Icon(Icons.inventory_2_rounded, color: primaryNavy, size: 22),
                        ),
                        title: Text(item['mappedName'], style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text('الكمية: ${item['qty']}', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                              Text('•', style: TextStyle(color: Colors.grey.shade400)),
                              Text('السعر: ${item['price']} ج', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            onPressed: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              setState(() => _invoiceItems.removeAt(index));
                            }
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // 🚀 الإجمالي وزرار الحفظ
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: primaryNavy, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('إجمالي الفاتورة:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white70)),
                          Text('${_totalAmount.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 22, color: brandOrange)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _invoiceItems.isEmpty ? null : _saveInvoice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandOrange,
                            disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                          label: const Text('اعتماد الفاتورة وتحديث المخزون', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        ),
                      ),
                    ],
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