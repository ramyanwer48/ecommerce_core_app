import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../purchases/services/purchase_service.dart';
import '../../admin/ui/widgets/google_image_picker_dialog.dart';

class ManualPurchaseScreen extends StatefulWidget {
  const ManualPurchaseScreen({super.key});

  @override
  State<ManualPurchaseScreen> createState() => _ManualPurchaseScreenState();
}

class _ManualPurchaseScreenState extends State<ManualPurchaseScreen> {
  static const String _suppliersCollection = 'suppliers';

  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _invoiceNumberController = TextEditingController();
  late TextEditingController _dateController;
  late DateTime _selectedDate;

  // حقول الخصم والضريبة
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _taxController = TextEditingController(text: '0');
  bool _isDiscountPercent = false;

  final List<Map<String, dynamic>> _invoiceItems = [];
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  // 🌟 القوائم الذكية المخصصة
  List<String> _suggestedSuppliers = [];
  List<String> _suggestedInvoiceNumbers = [];
  List<String> _suggestedProductNames = [];
  List<String> _suggestedQuantities = [];
  List<String> _suggestedPrices = [];

  // 🌟 قاعدة بيانات الأصناف (لمنع التكرار)
  List<Map<String, dynamic>> _allRegisteredProducts = [];

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

    // جلب الأصناف مرة واحدة في الخلفية
    FirebaseFirestore.instance.collection('products').get().then((snapshot) {
      if (mounted) {
        _allRegisteredProducts = snapshot.docs.map((doc) {
          var data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceNumberController.dispose();
    _dateController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    for (var item in _invoiceItems) {
      item['qtyController']?.dispose();
      item['conversionFactorController']?.dispose();
      item['priceController']?.dispose();
      item['sellingPriceController']?.dispose();
      item['nameController']?.dispose();
      item['nameFocus']?.dispose();
      item['qtyFocus']?.dispose();
      item['convFocus']?.dispose();
      item['priceFocus']?.dispose();
      item['sellFocus']?.dispose();
    }
    super.dispose();
  }

  // 💰 الحسابات المالية
  double get _grossAmount {
    return _invoiceItems.fold(0.0, (sum, item) {
      double price = double.tryParse(item['priceController'].text) ?? 0.0;
      int qty = int.tryParse(item['qtyController'].text) ?? 0;
      return sum + (price * qty);
    });
  }

  double get _discountAmount {
    double discountVal = double.tryParse(_discountController.text) ?? 0.0;
    if (_isDiscountPercent) {
      return _grossAmount * (discountVal / 100);
    }
    return discountVal;
  }

  double get _taxAmount {
    double taxPercent = double.tryParse(_taxController.text) ?? 0.0;
    return (_grossAmount - _discountAmount) * (taxPercent / 100);
  }

  double get _netAmount {
    return (_grossAmount - _discountAmount) + _taxAmount;
  }

  void _updateTotal() => setState(() {});

  void _clearForm() {
    setState(() {
      _supplierController.clear();
      _invoiceNumberController.clear();
      _discountController.text = '0';
      _taxController.text = '0';
      _selectedDate = DateTime.now();
      _dateController.text = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      _suggestedSuppliers.clear();
      _suggestedInvoiceNumbers.clear();
      _suggestedProductNames.clear();
      _suggestedQuantities.clear();
      _suggestedPrices.clear();

      for (var item in _invoiceItems) {
        item['nameController']?.dispose();
        item['qtyController']?.dispose();
        item['priceController']?.dispose();
        item['conversionFactorController']?.dispose();
        item['sellingPriceController']?.dispose();
        item['nameFocus']?.dispose();
        item['qtyFocus']?.dispose();
        item['convFocus']?.dispose();
        item['priceFocus']?.dispose();
        item['sellFocus']?.dispose();
      }
      _invoiceItems.clear();
    });
  }

  void _showCustomSnackBar(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14))),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  // 🚨 تحذير التكرار داخل نفس الفاتورة
  void _showInternalDuplicateWarning(int existingIndex, String prodName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('صنف مكرر بالفاتورة', style: TextStyle(fontFamily: 'Cairo', color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Text('الصنف "$prodName" مضاف بالفعل في هذه الفاتورة. هل تريد زيادة كميته بمقدار 1 بدلاً من إضافته كسطر جديد؟', style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            onPressed: () {
              setState(() {
                int currentQty = int.tryParse(_invoiceItems[existingIndex]['qtyController'].text) ?? 0;
                _invoiceItems[existingIndex]['qtyController'].text = (currentQty + 1).toString();
              });
              Navigator.pop(ctx);
              _showCustomSnackBar('تم زيادة الكمية بنجاح', true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: brandOrange),
            child: const Text('زيادة الكمية', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🧠 خوارزمية المطابقة المتقدمة (لمنع التكرار مع قاعدة البيانات)
  Map<String, dynamic>? _checkSimilarProduct(String inputName) {
    if (inputName.trim().length < 3) return null;

    Map<String, String> commonTranslations = {
      'samsung': 'سامسونج', 'iphone': 'ايفون', 'charger': 'شاحن', 'cable': 'كابل',
      'screen': 'شاشة', 'mouse': 'ماوس', 'cover': 'جراب', 'glass': 'اسكرينة'
    };

    String normalize(String s) {
      String temp = s.toLowerCase();
      commonTranslations.forEach((eng, ar) => temp = temp.replaceAll(eng, ar));
      return temp.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي').replaceAll(RegExp(r'[^a-z0-9ا-ي]'), '');
    }

    String normInput = normalize(inputName);

    for (var prod in _allRegisteredProducts) {
      String prodName = (prod['name'] ?? '').toString();
      String normProd = normalize(prodName);
      if (normProd.isEmpty) continue;

      if (normProd == normInput) return prod;
      if (normInput.length > 5 && normProd.length > 5 && (normProd.contains(normInput) || normInput.contains(normProd))) {
        return prod;
      }
    }
    return null;
  }

  void _showSimilarityWarningDialog(int itemIndex, Map<String, dynamic> similarProduct, String typedName) {
    FocusManager.instance.primaryFocus?.unfocus();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('صنف مشابه موجود', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black87),
            children: [
              const TextSpan(text: 'أنت تحاول إضافة:\n'),
              TextSpan(text: '"$typedName"\n\n', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
              const TextSpan(text: 'وهو يشبه الصنف المسجل:\n'),
              TextSpan(text: '"${similarProduct['name']}"\n\n', style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
              const TextSpan(text: 'هل ندمجهم معاً لتحديث المخزون؟'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('لا، اتركه جديد', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))
          ),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                var item = _invoiceItems[itemIndex];
                item['isNewProduct'] = false;
                item['mappedId'] = similarProduct['id'];
                item['mappedName'] = similarProduct['name'];
                item['rawAiName'] = similarProduct['name'];
                item['nameController'].text = similarProduct['name'];

                item['priceController'].text = (similarProduct['costPrice'] ?? 0).toString();
                item['sellingPriceController'].text = (similarProduct['price'] ?? 0).toString();

                item['imageUrls'] = similarProduct['imageUrls'] != null
                    ? List<String>.from(similarProduct['imageUrls'])
                    : (similarProduct['imageUrl'] != null ? [similarProduct['imageUrl']] : <String>[]);
              });
              Navigator.pop(ctx);
              _showCustomSnackBar('تم دمج الصنف بنجاح!', true);
            },
            icon: const Icon(Icons.merge_type_rounded, size: 18),
            label: const Text('نعم، ادمج الصنفين', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: brandOrange, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // 🚀 المحرك الذكي للتفريغ (النسخة المستقرة)
  Future<void> _extractTextFromClipboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    ClipboardData? clipboardData = await Clipboard.getData(Clipboard.kTextPlain);

    if (clipboardData != null && clipboardData.text != null && clipboardData.text!.trim().isNotEmpty) {
      String copiedText = clipboardData.text!;

      _suggestedSuppliers.clear();
      _suggestedInvoiceNumbers.clear();
      _suggestedProductNames.clear();
      _suggestedQuantities.clear();
      _suggestedPrices.clear();

      List<String> lines = LineSplitter.split(copiedText).toList();
      bool isFirstTextFound = false;

      RegExp standaloneNumbersRegex = RegExp(r'\b\d+([\.,]\d+)?\b(?!\s*(بوصة|متر|سم|مم|كجم|جرام|ملي|لتر|وات|inch|cm|mm|kg|g|ml|l|w|v|a)\b)', caseSensitive: false);

      for (String line in lines) {
        String cleanLine = line.trim();
        if (cleanLine.isEmpty) continue;

        RegExp invoiceRegex = RegExp(r'\b([a-zA-Z]+[-_]?\d+|\d+[-_]?[a-zA-Z]+|\#\d+)\b');
        for (var match in invoiceRegex.allMatches(cleanLine)) {
          _suggestedInvoiceNumbers.add(match.group(0)!);
        }

        for (var match in standaloneNumbersRegex.allMatches(cleanLine)) {
          String numStr = match.group(0)!.replaceAll(',', '.');
          double? val = double.tryParse(numStr);
          if (val != null) {
            if (numStr.contains('.') || val > 50) _suggestedPrices.add(numStr);
            if (!numStr.contains('.') && val > 0 && val <= 1000) _suggestedQuantities.add(numStr);
            if (!numStr.contains('.') && numStr.length >= 2) _suggestedInvoiceNumbers.add(numStr);
          }
        }

        if (RegExp(r'[a-zA-Zأ-ي]').hasMatch(cleanLine)) {
          String textOnly = cleanLine.replaceAll(standaloneNumbersRegex, '')
              .replaceAll(RegExp(r'^[-=*_]+|[-=*_]+$'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

          if (textOnly.length > 2) {
            if (!isFirstTextFound || textOnly.contains('شركة') || textOnly.contains('مؤسسة') || textOnly.contains('مورد') || textOnly.contains('محلات')) {
              _suggestedSuppliers.add(textOnly);
              isFirstTextFound = true;
            } else {
              _suggestedProductNames.add(textOnly);
            }
          }
        }
      }

      if (_suggestedSuppliers.isEmpty) _suggestedSuppliers.addAll(_suggestedProductNames);
      if (_suggestedProductNames.isEmpty) _suggestedProductNames.addAll(_suggestedSuppliers);
      if (_suggestedPrices.isEmpty) _suggestedPrices.addAll(_suggestedQuantities);
      if (_suggestedInvoiceNumbers.isEmpty) _suggestedInvoiceNumbers.addAll(_suggestedQuantities);

      setState(() {});
      _showCustomSnackBar('تم تفريغ الفاتورة! الأصناف تحتفظ بمقاساتها', true);
    } else {
      _showCustomSnackBar('الحافظة فارغة! قم بنسخ النص من الصورة أولاً', false);
    }
  }

  // 🧠 القائمة المنسدلة الأنيقة (بدون كيبورد)
  void _showSmartMenu(BuildContext context, TextEditingController controller, String fieldCategory, bool isItemName) {
    FocusManager.instance.primaryFocus?.unfocus();

    List<String> sourceList = [];
    String menuTitle = '';
    IconData titleIcon = Icons.list;

    switch (fieldCategory) {
      case 'supplier':
        sourceList = _suggestedSuppliers; menuTitle = 'أسماء الموردين'; titleIcon = Icons.store_mall_directory_rounded; break;
      case 'invoice':
        sourceList = _suggestedInvoiceNumbers; menuTitle = 'أرقام الفواتير'; titleIcon = Icons.receipt_long_rounded; break;
      case 'product':
        sourceList = _suggestedProductNames; menuTitle = 'أسماء الأصناف (بالمقاسات)'; titleIcon = Icons.inventory_2_rounded; break;
      case 'qty':
        sourceList = _suggestedQuantities; menuTitle = 'الكميات المستخرجة'; titleIcon = Icons.production_quantity_limits_rounded; break;
      case 'price':
        sourceList = _suggestedPrices; menuTitle = 'الأسعار المستخرجة'; titleIcon = Icons.monetization_on_rounded; break;
    }

    sourceList = sourceList.toSet().toList();

    if (sourceList.isEmpty) {
      _showCustomSnackBar('لم يتم العثور على بيانات لهذه الخانة', false);
      return;
    }

    List<PopupMenuEntry<String>> menuItems = [
      PopupMenuItem<String>(
          enabled: false,
          height: 35,
          child: Row(
            children: [
              Icon(titleIcon, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(menuTitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          )
      ),
      const PopupMenuDivider(height: 1),
    ];

    for (String item in sourceList) {
      menuItems.add(PopupMenuItem<String>(
          value: item,
          height: 45,
          child: Row(
            children: [
              Icon((fieldCategory == 'price' || fieldCategory == 'qty' || fieldCategory == 'invoice') ? Icons.tag_rounded : Icons.label_important_rounded, size: 16, color: brandOrange.withOpacity(0.7)),
              const SizedBox(width: 10),
              Expanded(child: Text(item, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy))),
            ],
          )
      ));
    }

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(button.localToGlobal(Offset(0, button.size.height), ancestor: overlay), button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay)),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: menuItems,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 8,
    ).then((String? value) {
      if (value != null) {
        controller.text = value;
        controller.selection = TextSelection.fromPosition(TextPosition(offset: value.length));

        if (isItemName) {
          int currentIndex = -1;
          for (int i = 0; i < _invoiceItems.length; i++) {
            if (_invoiceItems[i]['nameController'] == controller) {
              _invoiceItems[i]['mappedName'] = value;
              _invoiceItems[i]['rawAiName'] = value;
              currentIndex = i;
              break;
            }
          }

          if (currentIndex != -1 && _invoiceItems[currentIndex]['isNewProduct'] == true) {
            // فحص تكرار داخلي أولاً
            int internalExistIndex = _invoiceItems.indexWhere((item) => item['mappedName'] == value && _invoiceItems.indexOf(item) != currentIndex);
            if (internalExistIndex != -1) {
              _invoiceItems.removeAt(currentIndex);
              _showInternalDuplicateWarning(internalExistIndex, value);
            } else {
              // فحص مع الداتا بيز
              var similar = _checkSimilarProduct(value);
              if (similar != null) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  _showSimilarityWarningDialog(currentIndex, similar, value);
                });
              }
            }
          }
        }
        setState(() {});
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  Widget? _buildSmartIcon(BuildContext context, TextEditingController controller, {required String fieldCategory, bool isItemName = false}) {
    bool hasData = false;
    switch (fieldCategory) {
      case 'supplier': hasData = _suggestedSuppliers.isNotEmpty; break;
      case 'invoice': hasData = _suggestedInvoiceNumbers.isNotEmpty; break;
      case 'product': hasData = _suggestedProductNames.isNotEmpty; break;
      case 'qty': hasData = _suggestedQuantities.isNotEmpty; break;
      case 'price': hasData = _suggestedPrices.isNotEmpty; break;
    }

    if (!hasData) return null;

    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.touch_app_rounded, color: Colors.blue, size: 20),
      ),
      tooltip: 'اختيار من التفريغ',
      onPressed: () => _showSmartMenu(context, controller, fieldCategory, isItemName),
    );
  }

  void _showSupplierPickerModal() {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            Text('اختر من الموردين المسجلين', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy)),
            const Divider(),
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection(_suppliersCollection).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: brandOrange));
                  var docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(24.0), child: Text('لا يوجد موردون مسجلون حالياً', style: TextStyle(fontFamily: 'Cairo')));
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      String sName = (data['name'] ?? '').toString();
                      return ListTile(
                        leading: Icon(Icons.storefront, color: brandOrange),
                        title: Text(sName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        onTap: () {
                          setState(() => _supplierController.text = sName);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: primaryNavy, onPrimary: Colors.white, onSurface: Colors.black)), child: child!),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _addNewInlineProduct() {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _invoiceItems.insert(0, {
        'mappedName': '',
        'rawAiName': '',
        'mappedId': null,
        'isNewProduct': true,
        'mainCategory': 'الكل',
        'subCategory': 'الكل',
        'imageUrls': <String>[],
        'nameController': TextEditingController(),
        'conversionFactorController': TextEditingController(text: '1')..addListener(_updateTotal),
        'qtyController': TextEditingController(text: '1')..addListener(_updateTotal),
        'priceController': TextEditingController(text: '0')..addListener(_updateTotal),
        'sellingPriceController': TextEditingController(text: '0'),
        'nameFocus': FocusNode(),
        'qtyFocus': FocusNode(),
        'convFocus': FocusNode(),
        'priceFocus': FocusNode(),
        'sellFocus': FocusNode(),
      });
    });
  }

  void _openMultiSelectProductsDialog() {
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        List<Map<String, dynamic>> tempSelectedProducts = [];

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 32),
                          Text('تحديد الأصناف للفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black, width: 1.5)),
                            child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black, size: 16), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 10),

                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('products').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          var products = snapshot.data!.docs;
                          if (products.isEmpty) return const Center(child: Text('لا توجد منتجات مسجلة.', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)));

                          return ListView.builder(
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final doc = products[index];
                              final data = doc.data() as Map<String, dynamic>;

                              bool isAlreadyInInvoice = _invoiceItems.any((item) => item['mappedId'] == doc.id);
                              bool isSelectedHere = tempSelectedProducts.any((item) => item['mappedId'] == doc.id);
                              bool isChecked = isAlreadyInInvoice || isSelectedHere;

                              return CheckboxListTile(
                                activeColor: brandOrange,
                                checkColor: Colors.white,
                                title: Text(data['name'] ?? '', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isAlreadyInInvoice ? Colors.grey : Colors.black)),
                                subtitle: Text('السعر الحالي: ${data['costPrice'] ?? 0} ج.م', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600)),
                                value: isChecked,
                                onChanged: isAlreadyInInvoice ? null : (bool? value) {
                                  setSheetState(() {
                                    if (value == true) {
                                      tempSelectedProducts.add({
                                        'mappedId': doc.id,
                                        'mappedName': data['name'],
                                        'category': data['category'] ?? 'الكل',
                                        'subCategory': data['subCategory'] ?? 'الكل',
                                        'lastCostPrice': data['costPrice'] ?? 0.0,
                                        'lastSellingPrice': data['price'] ?? 0.0,
                                        'imageUrls': data['imageUrls'] != null
                                            ? List<String>.from(data['imageUrls'])
                                            : (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty ? [data['imageUrl']] : <String>[]),
                                      });
                                    } else {
                                      tempSelectedProducts.removeWhere((item) => item['mappedId'] == doc.id);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () {
                            setState(() {
                              for (var prod in tempSelectedProducts) {
                                _invoiceItems.insert(0, {
                                  'mappedName': prod['mappedName'],
                                  'rawAiName': prod['mappedName'],
                                  'mappedId': prod['mappedId'],
                                  'isNewProduct': false,
                                  'mainCategory': prod['category'],
                                  'subCategory': prod['subCategory'],
                                  'imageUrls': prod['imageUrls'],
                                  'nameController': TextEditingController(text: prod['mappedName']),
                                  'conversionFactorController': TextEditingController(text: '1')..addListener(_updateTotal),
                                  'qtyController': TextEditingController(text: '1')..addListener(_updateTotal),
                                  'priceController': TextEditingController(text: prod['lastCostPrice'].toString())..addListener(_updateTotal),
                                  'sellingPriceController': TextEditingController(text: prod['lastSellingPrice'].toString()),
                                  'nameFocus': FocusNode(),
                                  'qtyFocus': FocusNode(),
                                  'convFocus': FocusNode(),
                                  'priceFocus': FocusNode(),
                                  'sellFocus': FocusNode(),
                                });
                              }
                            });
                            Navigator.pop(context);
                          },
                          child: Text('إضافة (${tempSelectedProducts.length}) منتج للفاتورة', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showImageOptionsBottomSheet(int index, String productName) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Text('إضافة صورة لـ: $productName', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy)),
              const Divider(thickness: 1, height: 30),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: brandOrange.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.travel_explore, color: brandOrange, size: 24)),
                title: const Text('بحث من جوجل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  Future.delayed(const Duration(milliseconds: 150), () => _pickFromGoogleSearch(index, productName));
                },
              ),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.photo_library, color: Colors.blue, size: 24)),
                title: const Text('اختيار من المعرض', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.gallery, index);
                },
              ),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.teal, size: 24)),
                title: const Text('التقاط كاميرا', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.camera, index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromGoogleSearch(int index, String productName) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final List<String>? selectedImageUrls = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GoogleImagePickerDialog(productName: productName),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (selectedImageUrls != null && selectedImageUrls.isNotEmpty && mounted) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _invoiceItems[index]['imageUrls'] = selectedImageUrls);
          FocusManager.instance.primaryFocus?.unfocus();
          _showCustomSnackBar('تم ربط الصورة بنجاح', true);
        }
      });
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source, int index) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
    if (image == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: brandOrange),
            const SizedBox(height: 16),
            Text('جاري رفع الصورة...', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy)),
          ],
        ),
      ),
    );

    try {
      String fileName = 'products_images/manual_inv_${DateTime.now().millisecondsSinceEpoch}.jpg';
      TaskSnapshot snapshot = await FirebaseStorage.instance.ref().child(fileName).putFile(File(image.path));
      String downloadUrl = await snapshot.ref.getDownloadURL();
      if (mounted) {
        setState(() {
          List<String> currentUrls = List<String>.from(_invoiceItems[index]['imageUrls'] ?? []);
          currentUrls.add(downloadUrl);
          _invoiceItems[index]['imageUrls'] = currentUrls;
        });
        Navigator.pop(context);
        _showCustomSnackBar('تم رفع الصورة بنجاح', true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showCustomSnackBar('فشل الرفع: تأكد من الصلاحيات والإنترنت', false);
      }
    }
  }

  Future<void> _saveInvoice() async {
    if (_supplierController.text.trim().isEmpty) {
      _showCustomSnackBar('يجب إدخال اسم المورد', false);
      return;
    }
    if (_invoiceNumberController.text.trim().isEmpty) {
      _showCustomSnackBar('يجب إدخال رقم الفاتورة', false);
      return;
    }
    if (_invoiceItems.isEmpty) {
      _showCustomSnackBar('الفاتورة فارغة، أضف أصنافاً', false);
      return;
    }

    for (var item in _invoiceItems) {
      if (item['isNewProduct'] && (item['mappedName'] == null || item['mappedName'].trim().isEmpty)) {
        _showCustomSnackBar('يوجد صنف جديد بدون اسم، يرجى كتابة اسمه', false);
        return;
      }

      double price = double.tryParse(item['priceController'].text) ?? 0.0;
      int qty = int.tryParse(item['qtyController'].text) ?? 0;
      int conversion = int.tryParse(item['conversionFactorController'].text) ?? 1;

      if (price <= 0 || qty <= 0 || conversion <= 0) {
        _showCustomSnackBar('تأكد من صحة كميات وأسعار ${item['mappedName']}', false);
        return;
      }
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);

    try {
      List<Map<String, dynamic>> finalItemsToSave = _invoiceItems.map((item) {
        return {
          'mappedName': item['mappedName'],
          'rawAiName': item['rawAiName'],
          'mappedId': item['mappedId'],
          'isNewProduct': item['isNewProduct'],
          'mainCategory': item['mainCategory'],
          'subCategory': item['subCategory'],
          'conversionFactor': int.parse(item['conversionFactorController'].text),
          'imageUrls': item['imageUrls'],
          'qty': int.parse(item['qtyController'].text),
          'price': double.parse(item['priceController'].text),
          'sellingPrice': double.parse(item['sellingPriceController'].text),
        };
      }).toList();

      final purchaseService = PurchaseService();
      await purchaseService.processApprovedInvoice(
        supplierName: _supplierController.text.trim(),
        invoiceNumber: _invoiceNumberController.text.trim(),
        invoiceDate: _selectedDate,
        items: finalItemsToSave,
        source: 'manual_clipboard_smart',
      );

      if (mounted) {
        _showCustomSnackBar('تم ترحيل الفاتورة بنجاح', true);
        _clearForm();
      }
    } catch (e) {
      if (mounted) _showCustomSnackBar('حدث خطأ أثناء الترحيل', false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 📝 الدالة الأصلية والأساسية (تم استرجاع التنسيقات والألوان بنجاح)
  Widget _buildCenteredInput({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    required String fieldCategory,
    FocusNode? focusNode,
    Function(String)? onSubmitted,
    Color? labelColor,
    Color? fillColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w900, color: labelColor ?? primaryNavy)),
        const SizedBox(height: 6),
        Builder(
            builder: (iconContext) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                onFieldSubmitted: onSubmitted,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 16, color: Colors.black87),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: fillColor ?? bgSoftColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  suffixIcon: _buildSmartIcon(iconContext, controller, fieldCategory: fieldCategory),
                ),
              );
            }
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: _invoiceItems.isEmpty,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final bool? confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('تنبيه', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              content: const Text('لديك أصناف لم يتم حفظها، هل أنت متأكد من الخروج وفقدان الفاتورة؟', style: TextStyle(fontFamily: 'Cairo')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
              ],
            ),
          );
          if (confirm == true && context.mounted) {
            _invoiceItems.clear();
            setState(() {});
            Future.delayed(Duration.zero, () {
              if (context.mounted) Navigator.pop(context);
            });
          }
        },
        child: Scaffold(
          backgroundColor: bgSoftColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('إدخال فاتورة (يدوي)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            centerTitle: true,
            backgroundColor: primaryNavy,
            elevation: 0,
            actions: [
              if (Navigator.canPop(context))
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22), onPressed: () => Navigator.maybePop(context)),
                ),
              if (Navigator.canPop(context)) const SizedBox(width: 8),
            ],
          ),
          body: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: _isSaving
                ? Center(child: CircularProgressIndicator(color: brandOrange))
                : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('بيانات الفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            ElevatedButton.icon(
                              onPressed: _extractTextFromClipboard,
                              icon: const Icon(Icons.content_paste_rounded, size: 16),
                              label: const Text('تفريغ من الحافظة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryNavy.withOpacity(0.1),
                                foregroundColor: primaryNavy,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        Builder(
                            builder: (iconContext) {
                              return TextFormField(
                                controller: _supplierController,
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'اسم المورد / الشركة',
                                  labelStyle: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'),
                                  prefixIcon: Icon(Icons.store_rounded, color: primaryNavy),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_buildSmartIcon(iconContext, _supplierController, fieldCategory: 'supplier') != null)
                                        _buildSmartIcon(iconContext, _supplierController, fieldCategory: 'supplier')!,
                                      IconButton(tooltip: 'اختر من الموردين المسجلين', icon: Icon(Icons.arrow_drop_down_circle_outlined, color: brandOrange), onPressed: _showSupplierPickerModal),
                                    ],
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: bgSoftColor,
                                ),
                              );
                            }
                        ),
                        const SizedBox(height: 12),
                        Builder(
                            builder: (iconContext) {
                              return TextFormField(
                                controller: _invoiceNumberController,
                                keyboardType: TextInputType.text,
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'رقم الفاتورة (مطلوب)',
                                  labelStyle: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'),
                                  prefixIcon: const Icon(Icons.numbers_rounded, color: Colors.grey),
                                  suffixIcon: _buildSmartIcon(iconContext, _invoiceNumberController, fieldCategory: 'invoice'),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: bgSoftColor,
                                ),
                              );
                            }
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          onTap: () => _selectDate(context),
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'التاريخ',
                            labelStyle: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'),
                            prefixIcon: Icon(Icons.calendar_month_rounded, color: brandOrange),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: bgSoftColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _openMultiSelectProductsDialog,
                          icon: const Icon(Icons.checklist_rtl_rounded, size: 20),
                          label: const Text('تحديد الأصناف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(backgroundColor: brandOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: ElevatedButton.icon(
                          onPressed: _addNewInlineProduct,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryNavy.withOpacity(0.1), foregroundColor: primaryNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                        ),
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
                          const Text('حدد الأصناف وابدأ التسعير..', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold)),
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
                      List<String> productUrls = List<String>.from(item['imageUrls'] ?? []);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: item['isNewProduct'] ? brandOrange.withOpacity(0.5) : Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🌟 الترقيم المسلسل هنا
                                Container(
                                  width: 26,
                                  height: 26,
                                  margin: const EdgeInsets.only(left: 8, top: 14),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: primaryNavy.withOpacity(0.1), shape: BoxShape.circle),
                                  child: Text('${_invoiceItems.length - index}', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: primaryNavy)),
                                ),

                                GestureDetector(
                                  onTap: () => _showImageOptionsBottomSheet(index, item['mappedName'] ?? 'صنف جديد'),
                                  child: Container(
                                    width: 55,
                                    height: 55,
                                    decoration: BoxDecoration(color: bgSoftColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: productUrls.isNotEmpty
                                          ? Image.network(productUrls.first, fit: BoxFit.cover)
                                          : Icon(Icons.add_a_photo_rounded, color: Colors.grey.shade400, size: 24),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      item['isNewProduct']
                                          ? Builder(
                                          builder: (iconContext) {
                                            return TextFormField(
                                              controller: item['nameController'],
                                              focusNode: item['nameFocus'],
                                              textInputAction: TextInputAction.next,
                                              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(item['qtyFocus']),
                                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: brandOrange),
                                              decoration: InputDecoration(
                                                hintText: 'اكتب اسم الصنف الجديد...',
                                                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                                suffixIcon: _buildSmartIcon(iconContext, item['nameController'], fieldCategory: 'product', isItemName: true),
                                              ),
                                              onChanged: (val) {
                                                item['mappedName'] = val;
                                                item['rawAiName'] = val;
                                                if (val.length > 3) {
                                                  var similar = _checkSimilarProduct(val);
                                                  if (similar != null) {
                                                    Future.delayed(const Duration(milliseconds: 500), () {
                                                      if (mounted && item['mappedName'] == val) {
                                                        _showSimilarityWarningDialog(index, similar, val);
                                                      }
                                                    });
                                                  }
                                                }
                                              },
                                            );
                                          }
                                      )
                                          : Text(item['mappedName'], style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: primaryNavy, height: 1.2)),
                                      if (item['isNewProduct'])
                                        Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: brandOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                          child: Text('جديد', style: TextStyle(color: brandOrange, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 22), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  setState(() => _invoiceItems.removeAt(index));
                                }),
                              ],
                            ),
                            const Divider(height: 20),

                            Row(
                              children: [
                                Expanded(child: _buildCenteredInput(context: context, label: 'الكمية (كرتونة)', controller: item['qtyController'], focusNode: item['qtyFocus'], keyboardType: TextInputType.number, textInputAction: TextInputAction.next, fieldCategory: 'qty', onSubmitted: (_) => FocusScope.of(context).requestFocus(item['convFocus']))),
                                const SizedBox(width: 12),
                                Expanded(child: _buildCenteredInput(context: context, label: 'عدد القطع بالكرتونة', controller: item['conversionFactorController'], focusNode: item['convFocus'], keyboardType: TextInputType.number, textInputAction: TextInputAction.next, fieldCategory: 'qty', onSubmitted: (_) => FocusScope.of(context).requestFocus(item['priceFocus']))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildCenteredInput(context: context, label: 'سعر الشراء (للكرتونة)', controller: item['priceController'], focusNode: item['priceFocus'], keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next, fieldCategory: 'price', onSubmitted: (_) => FocusScope.of(context).requestFocus(item['sellFocus']))),
                                const SizedBox(width: 12),
                                Expanded(child: _buildCenteredInput(context: context, label: 'سعر البيع (للقطعة)', controller: item['sellingPriceController'], focusNode: item['sellFocus'], keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.done, fieldCategory: 'price', labelColor: brandOrange, fillColor: Colors.orange.withOpacity(0.08), onSubmitted: (_) {
                                  if (item['isNewProduct']) {
                                    _addNewInlineProduct();
                                  } else {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                  }
                                })),
                              ],
                            ),

                            // 🌟 إجمالي الصنف
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('إجمالي قيمة الصنف:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text(
                                  '${((double.tryParse(item['priceController'].text) ?? 0.0) * (int.tryParse(item['qtyController'].text) ?? 0)).toStringAsFixed(2)} ج.م',
                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: primaryNavy, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // 🌟 الحسابات المالية الدقيقة (الخصم والضريبة)
                  if (_invoiceItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _discountController, keyboardType: TextInputType.number, onChanged: (v) => _updateTotal(), decoration: InputDecoration(labelText: 'الخصم', suffixIcon: IconButton(icon: Icon(_isDiscountPercent ? Icons.percent : Icons.attach_money), onPressed: () => setState(() => _isDiscountPercent = !_isDiscountPercent)), border: const OutlineInputBorder()))),
                              const SizedBox(width: 12),
                              Expanded(child: TextFormField(controller: _taxController, keyboardType: TextInputType.number, onChanged: (v) => _updateTotal(), decoration: const InputDecoration(labelText: 'ضريبة (%)', suffixIcon: Icon(Icons.percent), border: OutlineInputBorder()))),
                            ],
                          ),
                          const Divider(height: 30),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي قبل الخصم:', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)), Text('${_grossAmount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold))]),
                          if (_discountAmount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الخصم:', style: TextStyle(fontFamily: 'Cairo', color: Colors.green)), Text('-${_discountAmount.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.green))]),
                          if (_taxAmount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الضريبة:', style: TextStyle(fontFamily: 'Cairo', color: Colors.red)), Text('+${_taxAmount.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.red))]),
                          const Divider(),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الصافي للدفع:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)), Text('${_netAmount.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 22, color: brandOrange))]),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _invoiceItems.isEmpty ? null : _saveInvoice,
                      style: ElevatedButton.styleFrom(backgroundColor: brandOrange, disabledBackgroundColor: Colors.grey.withOpacity(0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                      label: const Text('اعتماد الفاتورة وتحديث المخزون', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}