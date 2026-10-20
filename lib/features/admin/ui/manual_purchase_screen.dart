import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../purchases/services/purchase_service.dart';

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

  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _taxController = TextEditingController(text: '0');
  bool _isDiscountPercent = false;

  final List<Map<String, dynamic>> _invoiceItems = [];
  bool _isSaving = false;

  final ScrollController _scrollController = ScrollController();

  double? _currentGlobalMargin;

  List<String> _suggestedSuppliers = [];
  List<String> _suggestedInvoiceNumbers = [];
  List<String> _suggestedProductNames = [];
  List<String> _suggestedQuantities = [];
  List<String> _suggestedPrices = [];

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
    _scrollController.dispose();
    for (var item in _invoiceItems) {
      (item['qtyController'] as TextEditingController?)?.dispose();
      (item['conversionFactorController'] as TextEditingController?)?.dispose();
      (item['priceController'] as TextEditingController?)?.dispose();
      (item['sellingPriceController'] as TextEditingController?)?.dispose();
      (item['nameController'] as TextEditingController?)?.dispose();
      (item['nameFocus'] as FocusNode?)?.dispose();
      (item['qtyFocus'] as FocusNode?)?.dispose();
      (item['convFocus'] as FocusNode?)?.dispose();
      (item['priceFocus'] as FocusNode?)?.dispose();
      (item['sellFocus'] as FocusNode?)?.dispose();
    }
    super.dispose();
  }

  String _formatNumber(dynamic val) {
    if (val == null) return '0';
    double? number = double.tryParse(val.toString());
    if (number == null) return val.toString();
    if (number == number.toInt()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(2);
  }

  double get _grossAmount {
    return _invoiceItems.fold(0.0, (totalSum, item) {
      double price = double.tryParse((item['priceController'] as TextEditingController).text) ?? 0.0;
      int qty = int.tryParse((item['qtyController'] as TextEditingController).text) ?? 0;
      return totalSum + (price * qty);
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

  void _calculateSellingPrice(Map<String, dynamic> item, double percentage) {
    double costPrice = double.tryParse((item['priceController'] as TextEditingController).text) ?? 0.0;
    double conversion = double.tryParse((item['conversionFactorController'] as TextEditingController).text) ?? 1.0;
    if (conversion <= 0) conversion = 1.0;

    double unitCost = costPrice / conversion;
    double sellingPrice = unitCost + (unitCost * (percentage / 100));
    (item['sellingPriceController'] as TextEditingController).text = _formatNumber(sellingPrice);
  }

  void _applyGlobalProfitMargin(double percentage) {
    setState(() {
      _currentGlobalMargin = percentage;
      for (var item in _invoiceItems) {
        if (item['isCustomMargin'] != true) {
          item['itemMargin'] = percentage;
          _calculateSellingPrice(item, percentage);
        }
      }
    });
    _showCustomSnackBar('تم تطبيق نسبة $percentage% على الأصناف التلقائية', true);
  }

  void _applyItemProfitMargin(int index, double percentage) {
    setState(() {
      var item = _invoiceItems[index];
      item['itemMargin'] = percentage;

      if (_currentGlobalMargin != null && percentage == _currentGlobalMargin) {
        item['isCustomMargin'] = false;
      } else {
        item['isCustomMargin'] = true;
      }

      _calculateSellingPrice(item, percentage);
    });
    _showCustomSnackBar('تم تثبيت نسبة $percentage% لهذا الصنف', true);
  }

  void _showProfitMarginModal({int? targetItemIndex}) {
    FocusManager.instance.primaryFocus?.unfocus();
    List<double> presetMargins = [10, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 32),
                    Text(
                      targetItemIndex == null ? 'اختر نسبة الربح العامة للفاتورة' : 'اختر نسبة الربح للصنف',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black, width: 1.5)),
                      child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black, size: 16), onPressed: () => Navigator.pop(ctx), padding: EdgeInsets.zero),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: presetMargins.map((margin) => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bgSoftColor,
                      foregroundColor: primaryNavy,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (targetItemIndex == null) {
                        _applyGlobalProfitMargin(margin);
                      } else {
                        _applyItemProfitMargin(targetItemIndex, margin);
                      }
                    },
                    child: Text('$margin%', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  )).toList(),
                ),
                const Divider(height: 30),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCustomPercentageDialog(targetItemIndex: targetItemIndex);
                  },
                  icon: Icon(Icons.add_rounded, color: brandOrange),
                  label: Text('إضافة نسبة مخصصة...', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: brandOrange)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: brandOrange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomPercentageDialog({int? targetItemIndex}) {
    TextEditingController customController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('نسبة ربح مخصصة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: customController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'أدخل النسبة المئوية (مثال: 13.5)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            onPressed: () {
              double? val = double.tryParse(customController.text);
              if (val != null) {
                Navigator.pop(ctx);
                if (targetItemIndex == null) {
                  _applyGlobalProfitMargin(val);
                } else {
                  _applyItemProfitMargin(targetItemIndex, val);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: brandOrange),
            child: const Text('تطبيق', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
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

  Future<void> _extractTextFromClipboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    ClipboardData? clipboardData = await Clipboard.getData(Clipboard.kTextPlain);

    if (clipboardData == null || clipboardData.text == null || clipboardData.text!.trim().isEmpty) {
      _showCustomSnackBar('الحافظة فارغة!', false);
      return;
    }

    String text = clipboardData.text!;
    _suggestedSuppliers.clear();
    _suggestedInvoiceNumbers.clear();
    _suggestedProductNames.clear();
    _suggestedQuantities.clear();
    _suggestedPrices.clear();

    List<String> lines = text.split(RegExp(r'\r?\n'));

    for (String line in lines) {
      String cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;

      if (RegExp(r'(?:مورد|المورد|للمورد|شركة|محلات|مؤسسة|العميل)[\s:*-]*(.+)').hasMatch(cleanLine)) {
        String supplierName = cleanLine.replaceAll(RegExp(r'(اسم|المورد|للمورد|شركة|محلات|مؤسسة|العميل|جديد|:|-|\(|\))'), '').trim();
        if (supplierName.length > 2 && !RegExp(r'^\d+$').hasMatch(supplierName)) {
          _suggestedSuppliers.add(supplierName);
        }
        continue;
      }

      var invMatch = RegExp(r'(?:فاتورة|رقم|inv|invoice)[\s:#*-]*([a-zA-Z0-9-]+)', caseSensitive: false).firstMatch(cleanLine);
      if (invMatch != null) {
        String invNumber = invMatch.group(1)!.trim();
        if (invNumber.length > 2 && !RegExp(r'^(202[0-9]|203[0-9])$').hasMatch(invNumber)) {
          _suggestedInvoiceNumbers.add(invNumber);
          cleanLine = cleanLine.replaceAll(invNumber, '').trim();
        }
      }

      if (RegExp(r'(تاريخ|وقت|إجمالي|اجمالي|صافي|خصم|ضريبة|تليفون|هاتف|توقيع|مدفوع|متبقي|مطلوب|ملاحظة|النظام|المقترح|تغير|تكلفة|مشتريات|سابقة)').hasMatch(cleanLine)) {
        continue;
      }

      RegExp numRegex = RegExp(r'\b\d+(\.\d+)?\b');
      Iterable<Match> numMatches = numRegex.allMatches(cleanLine);
      for (Match m in numMatches) {
        double? val = double.tryParse(m.group(0)!);
        if (val != null) {
          if (val > 100 || m.group(0)!.contains('.')) {
            _suggestedPrices.add(_formatNumber(val));
          } else if (val > 0 && val <= 100) {
            _suggestedQuantities.add(_formatNumber(val));
          }
        }
      }

      String productNameOnly = cleanLine.replaceAll(numRegex, '')
          .replaceAll(RegExp(r'[-=*_:/\\+!@#(),\[\]]+'), ' ')
          .replaceAll(RegExp(r'\b(قطعة|كرتونة|كيس|جنيه|ج\.م|egp|كمية|شراء|بيع|سعر|بوصة|م|سم|كجم|جم|لتر|ملي)\b', caseSensitive: false), '')
          .trim();

      productNameOnly = productNameOnly.replaceAll(RegExp(r'\s+'), ' ');

      if (productNameOnly.length > 3 && RegExp(r'[a-zA-Zأ-ي]{3,}').hasMatch(productNameOnly)) {
        if (!RegExp(r'^(ح ب|بدل|سعر|بيع|شراء|اجمالي|خصم|ضريبة|صافي|مجموع|فاتورة|رقم)$').hasMatch(productNameOnly)) {
          _suggestedProductNames.add(productNameOnly);
        }
      }
    }

    _suggestedSuppliers = _suggestedSuppliers.toSet().toList();
    _suggestedInvoiceNumbers = _suggestedInvoiceNumbers.toSet().toList();
    _suggestedProductNames = _suggestedProductNames.toSet().toList();
    _suggestedQuantities = _suggestedQuantities.toSet().toList();
    _suggestedPrices = _suggestedPrices.toSet().toList();

    setState(() {});

    if (_suggestedProductNames.isEmpty && _suggestedPrices.isEmpty && _suggestedSuppliers.isEmpty) {
      _showCustomSnackBar('لم يتم العثور على بيانات مفيدة في النص', false);
    } else {
      _showCustomSnackBar('تم تفريغ الفاتورة بنجاح', true);
      _addNewInlineProduct();
    }
  }

  void _clearForm() {
    setState(() {
      _supplierController.clear();
      _invoiceNumberController.clear();
      _discountController.text = '0';
      _taxController.text = '0';
      _currentGlobalMargin = null;
      _selectedDate = DateTime.now();
      _dateController.text = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      _suggestedSuppliers.clear();
      _suggestedInvoiceNumbers.clear();
      _suggestedProductNames.clear();
      _suggestedQuantities.clear();
      _suggestedPrices.clear();

      for (var item in _invoiceItems) {
        (item['nameController'] as TextEditingController?)?.dispose();
        (item['qtyController'] as TextEditingController?)?.dispose();
        (item['priceController'] as TextEditingController?)?.dispose();
        (item['conversionFactorController'] as TextEditingController?)?.dispose();
        (item['sellingPriceController'] as TextEditingController?)?.dispose();
        (item['nameFocus'] as FocusNode?)?.dispose();
        (item['qtyFocus'] as FocusNode?)?.dispose();
        (item['convFocus'] as FocusNode?)?.dispose();
        (item['priceFocus'] as FocusNode?)?.dispose();
        (item['sellFocus'] as FocusNode?)?.dispose();
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

  void _showSmartMenu(BuildContext context, TextEditingController controller, String fieldCategory, bool isItemName) {
    FocusManager.instance.primaryFocus?.unfocus();

    List<String> sourceList = [];
    String menuTitle = '';
    IconData titleIcon = Icons.list;

    switch (fieldCategory) {
      case 'supplier':
        sourceList = _suggestedSuppliers; menuTitle = 'أسماء الموردين المستخرجة'; titleIcon = Icons.store_mall_directory_rounded; break;
      case 'invoice':
        sourceList = _suggestedInvoiceNumbers; menuTitle = 'أرقام الفواتير المستخرجة'; titleIcon = Icons.receipt_long_rounded; break;
      case 'product':
        sourceList = _suggestedProductNames; menuTitle = 'أسماء الأصناف المستخرجة'; titleIcon = Icons.inventory_2_rounded; break;
      case 'qty':
        sourceList = _suggestedQuantities; menuTitle = 'الكميات المستخرجة'; titleIcon = Icons.production_quantity_limits_rounded; break;
      case 'price':
        sourceList = _suggestedPrices; menuTitle = 'الأسعار المستخرجة'; titleIcon = Icons.monetization_on_rounded; break;
    }

    sourceList = sourceList.toSet().toList();

    if (sourceList.isEmpty) {
      _showCustomSnackBar('لم يتم العثور على بيانات نظيفة لهذه الخانة', false);
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon((fieldCategory == 'price' || fieldCategory == 'qty' || fieldCategory == 'invoice') ? Icons.tag_rounded : Icons.label_important_rounded, size: 16, color: brandOrange.withValues(alpha: 0.7)),
              const SizedBox(width: 10),
              Expanded(
                child: fieldCategory == 'supplier'
                    ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    item,
                    maxLines: 1,
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy),
                  ),
                )
                    : Text(
                  item,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy),
                ),
              ),
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
        controller.selection = const TextSelection.collapsed(offset: 0);

        if (isItemName) {
          int currentIndex = _invoiceItems.indexWhere((item) => item['nameController'] == controller);
          if (currentIndex != -1 && _invoiceItems[currentIndex]['isNewProduct'] == true) {
            int internalExistIndex = _invoiceItems.indexWhere((item) => item['mappedName'] == value && _invoiceItems.indexOf(item) != currentIndex);
            if (internalExistIndex != -1) {
              _invoiceItems.removeAt(currentIndex);
              _showInternalDuplicateWarning(internalExistIndex, value);
            } else {
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
        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.touch_app_rounded, color: Colors.blue, size: 20),
      ),
      tooltip: 'اختيار من التفريغ',
      onPressed: () => _showSmartMenu(context, controller, fieldCategory, isItemName),
    );
  }

  // 🌟 تعديل شاشة اختيار الأصناف لتكون منسجمة مع الهوية (كحلي وبرتقالي)
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
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24))
                ),
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
                          // عنوان رئيسي بالكحلي الخاص بالهوية
                          Text(
                              'تحديد الأصناف للفاتورة',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: primaryNavy
                              )
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: primaryNavy, width: 1.5)
                            ),
                            child: IconButton(
                                icon: Icon(Icons.close_rounded, color: primaryNavy, size: 16),
                                onPressed: () => Navigator.pop(context),
                                padding: EdgeInsets.zero
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 10),

                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('products').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: primaryNavy));
                          var products = snapshot.data!.docs;
                          if (products.isEmpty) {
                            return const Center(
                              child: Text(
                                  'لا توجد منتجات مسجلة.',
                                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.grey)
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final doc = products[index];
                              final data = doc.data() as Map<String, dynamic>;

                              bool isAlreadyInInvoice = _invoiceItems.any((item) => item['mappedId'] == doc.id);
                              bool isSelectedHere = tempSelectedProducts.any((item) => item['mappedId'] == doc.id);
                              bool isChecked = isAlreadyInInvoice || isSelectedHere;

                              String? thumbUrl;
                              if (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty) {
                                thumbUrl = data['imageUrls'][0];
                              } else if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
                                thumbUrl = data['imageUrl'];
                              }

                              return CheckboxListTile(
                                activeColor: primaryNavy, // 🌟 لون التشيك بوكس بالكحلي الفخم
                                checkColor: Colors.white,
                                secondary: thumbUrl != null
                                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(thumbUrl, width: 45, height: 45, fit: BoxFit.cover))
                                    : Container(width: 45, height: 45, decoration: BoxDecoration(color: bgSoftColor, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.inventory_2_rounded, color: primaryNavy.withValues(alpha: 0.5))),
                                // 🌟 أسماء المنتجات بخط عريض ولون الهوية الكحلي
                                title: Text(
                                    data['name'] ?? '',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isAlreadyInInvoice ? Colors.grey : primaryNavy,
                                    )
                                ),
                                // 🌟 السعر بلون هادئ ومنسق
                                subtitle: Text(
                                    'السعر الحالي: ${_formatNumber(data['costPrice'] ?? 0)} ج.م',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600
                                    )
                                ),
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

                    // 🌟 زر الإضافة السفلي في القائمة بلون الهوية الكحلي الفخم
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryNavy,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() {
                              for (var prod in tempSelectedProducts) {
                                var newItem = {
                                  'mappedName': prod['mappedName'],
                                  'rawAiName': prod['mappedName'],
                                  'mappedId': prod['mappedId'],
                                  'isNewProduct': false,
                                  'mainCategory': prod['category'],
                                  'subCategory': prod['subCategory'],
                                  'imageUrls': prod['imageUrls'],
                                  'itemMargin': _currentGlobalMargin,
                                  'isCustomMargin': false,
                                  'nameController': TextEditingController(text: prod['mappedName']),
                                  'conversionFactorController': TextEditingController(text: '1'),
                                  'qtyController': TextEditingController(text: '1'),
                                  'priceController': TextEditingController(text: _formatNumber(prod['lastCostPrice'])),
                                  'sellingPriceController': TextEditingController(text: _formatNumber(prod['lastSellingPrice'])),
                                  'nameFocus': FocusNode(),
                                  'qtyFocus': FocusNode(),
                                  'convFocus': FocusNode(),
                                  'priceFocus': FocusNode(),
                                  'sellFocus': FocusNode(),
                                };

                                (newItem['priceController'] as TextEditingController).addListener(() {
                                  _updateTotal();
                                  double? currentMargin = newItem['itemMargin'] as double? ?? _currentGlobalMargin;
                                  if (currentMargin != null) {
                                    _calculateSellingPrice(newItem, currentMargin);
                                  }
                                });
                                (newItem['conversionFactorController'] as TextEditingController).addListener(() {
                                  _updateTotal();
                                  double? currentMargin = newItem['itemMargin'] as double? ?? _currentGlobalMargin;
                                  if (currentMargin != null) {
                                    _calculateSellingPrice(newItem, currentMargin);
                                  }
                                });
                                (newItem['qtyController'] as TextEditingController).addListener(() {
                                  _updateTotal();
                                });

                                _invoiceItems.add(newItem);
                              }
                            });
                            Navigator.pop(context);

                          },
                          child: Text(
                              'إضافة (${tempSelectedProducts.length}) منتج للفاتورة',
                              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)
                          ),
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 150), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 400,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _addNewInlineProduct() {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      var newItem = {
        'mappedName': '',
        'rawAiName': '',
        'mappedId': null,
        'isNewProduct': true,
        'mainCategory': 'الكل',
        'subCategory': 'الكل',
        'imageUrls': <String>[],
        'itemMargin': _currentGlobalMargin,
        'isCustomMargin': false,
        'nameController': TextEditingController(),
        'conversionFactorController': TextEditingController(text: '1'),
        'qtyController': TextEditingController(text: '1'),
        'priceController': TextEditingController(text: '0'),
        'sellingPriceController': TextEditingController(text: '0'),
        'nameFocus': FocusNode(),
        'qtyFocus': FocusNode(),
        'convFocus': FocusNode(),
        'priceFocus': FocusNode(),
        'sellFocus': FocusNode(),
      };

      (newItem['priceController'] as TextEditingController).addListener(() {
        _updateTotal();
        double? currentMargin = newItem['itemMargin'] as double? ?? _currentGlobalMargin;
        if (currentMargin != null) {
          _calculateSellingPrice(newItem, currentMargin);
        }
      });
      (newItem['conversionFactorController'] as TextEditingController).addListener(() {
        _updateTotal();
        double? currentMargin = newItem['itemMargin'] as double? ?? _currentGlobalMargin;
        if (currentMargin != null) {
          _calculateSellingPrice(newItem, currentMargin);
        }
      });
      (newItem['qtyController'] as TextEditingController).addListener(() {
        _updateTotal();
      });

      _invoiceItems.add(newItem);
    });
  }

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
                int currentQty = int.tryParse((_invoiceItems[existingIndex]['qtyController'] as TextEditingController).text) ?? 0;
                (_invoiceItems[existingIndex]['qtyController'] as TextEditingController).text = (currentQty + 1).toString();
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
                (item['nameController'] as TextEditingController).text = similarProduct['name'];

                (item['priceController'] as TextEditingController).text = _formatNumber(similarProduct['costPrice'] ?? 0);
                (item['sellingPriceController'] as TextEditingController).text = _formatNumber(similarProduct['price'] ?? 0);

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

  Future<void> _saveInvoice() async {
    if (_supplierController.text.trim().isEmpty) {
      _showCustomSnackBar('يجب إدخال اسم المورد', false);
      return;
    }
    if (_invoiceNumberController.text.trim().isEmpty) {
      _showCustomSnackBar('رقم الفاتورة مطلوب', false);
      return;
    }
    if (_invoiceItems.isEmpty) {
      _showCustomSnackBar('الفاتورة فارغة، أضف أصنافاً', false);
      return;
    }

    for (var item in _invoiceItems) {
      if (item['isNewProduct'] && ((item['nameController'] as TextEditingController).text.trim().isEmpty)) {
        _showCustomSnackBar('يوجد صنف جديد بدون اسم، يرجى كتابة اسمه', false);
        return;
      }

      double price = double.tryParse((item['priceController'] as TextEditingController).text) ?? 0.0;
      int qty = int.tryParse((item['qtyController'] as TextEditingController).text) ?? 0;
      int conversion = int.tryParse((item['conversionFactorController'] as TextEditingController).text) ?? 1;

      if (price <= 0 || qty <= 0 || conversion <= 0) {
        _showCustomSnackBar('تأكد من صحة كميات وأسعار الصنف', false);
        return;
      }
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);

    try {
      List<Map<String, dynamic>> finalItemsToSave = _invoiceItems.map((item) {
        return {
          'mappedName': item['isNewProduct'] ? (item['nameController'] as TextEditingController).text : item['mappedName'],
          'rawAiName': item['rawAiName'],
          'mappedId': item['mappedId'],
          'isNewProduct': item['isNewProduct'],
          'mainCategory': item['mainCategory'],
          'subCategory': item['subCategory'],
          'conversionFactor': int.parse((item['conversionFactorController'] as TextEditingController).text),
          'imageUrls': item['imageUrls'] ?? <String>[],
          'qty': int.parse((item['qtyController'] as TextEditingController).text),
          'price': double.parse((item['priceController'] as TextEditingController).text),
          'sellingPrice': double.parse((item['sellingPriceController'] as TextEditingController).text),
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
        _showCustomSnackBar('تم اعتماد الفاتورة بنجاح', true);
        _clearForm();
      }
    } catch (e) {
      if (mounted) _showCustomSnackBar('حدث خطأ أثناء الاعتماد', false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: _invoiceItems.isEmpty,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final bool? confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: brandOrange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.warning_amber_rounded, color: brandOrange, size: 38),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'تنبيه هام!',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 20, color: primaryNavy),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'لديك أصناف لم يتم حفظها، هل أنت متأكد من الخروج وفقدان بيانات الفاتورة؟',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey.shade700, height: 1.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade400, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text('خروج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red.shade600, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryNavy,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
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
                                backgroundColor: primaryNavy.withValues(alpha: 0.1),
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
                                maxLines: 2,
                                minLines: 1,
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'اسم المورد / الشركة',
                                  labelStyle: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'),
                                  prefixIcon: Icon(Icons.store_rounded, color: primaryNavy),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_buildSmartIcon(iconContext, _supplierController, fieldCategory: 'supplier') != null)
                                        _buildSmartIcon(iconContext, _supplierController, fieldCategory: 'supplier')!,
                                      IconButton(
                                        tooltip: 'اختر من الموردين المسجلين',
                                        icon: Icon(Icons.arrow_drop_down_circle_outlined, color: brandOrange),
                                        onPressed: _showSupplierPickerModal,
                                      ),
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

                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openMultiSelectProductsDialog,
                          icon: const Icon(Icons.checklist_rtl_rounded, size: 20),
                          label: const Text('تحديد الأصناف من المخزن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandOrange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showProfitMarginModal(),
                          icon: const Icon(Icons.percent_rounded, size: 20),
                          label: Text(
                            _currentGlobalMargin == null
                                ? 'نسبة الربح العامة للفاتورة (اضغط للتطبيق)'
                                : 'نسبة الربح المطبقة: $_currentGlobalMargin% (اضغط للتغيير)',
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentGlobalMargin == null ? Colors.teal : Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.teal.shade200, width: 1.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            elevation: 0,
                          ),
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
                      bool isCustom = item['isCustomMargin'] == true;

                      int qtyCarton = int.tryParse((item['qtyController'] as TextEditingController).text) ?? 0;
                      int convFactor = int.tryParse((item['conversionFactorController'] as TextEditingController).text) ?? 1;
                      if (convFactor <= 0) convFactor = 1;
                      int totalPieces = qtyCarton * convFactor;

                      double cartonPrice = double.tryParse((item['priceController'] as TextEditingController).text) ?? 0.0;
                      double unitCost = cartonPrice / convFactor;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: item['isNewProduct'] ? brandOrange.withValues(alpha: 0.8) : primaryNavy.withValues(alpha: 0.3), width: 2),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 3))]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  margin: const EdgeInsets.only(left: 8, top: 4),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: primaryNavy.withValues(alpha: 0.1), shape: BoxShape.circle),
                                  child: Text('${index + 1}', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: primaryNavy)),
                                ),

                                if (!item['isNewProduct'] && productUrls.isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(productUrls.first, width: 45, height: 45, fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox()),
                                  ),
                                  const SizedBox(width: 8),
                                ],

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      item['isNewProduct']
                                          ? Builder(
                                          builder: (iconContext) {
                                            return TextFormField(
                                              controller: item['nameController'] as TextEditingController,
                                              focusNode: item['nameFocus'] as FocusNode,
                                              textInputAction: TextInputAction.next,
                                              maxLines: 2,
                                              minLines: 1,
                                              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(item['qtyFocus'] as FocusNode),
                                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: brandOrange),
                                              decoration: InputDecoration(
                                                hintText: 'اكتب اسم الصنف هنا...',
                                                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                                                filled: true,
                                                fillColor: bgSoftColor,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                                suffixIcon: _buildSmartIcon(iconContext, item['nameController'] as TextEditingController, fieldCategory: 'product', isItemName: true),
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
                                          : Text(item['mappedName'], style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy, height: 1.2)),

                                      if (item['isNewProduct'])
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text('صنف جديد', style: TextStyle(color: brandOrange, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black, width: 1.5)),
                                  child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black, size: 16), onPressed: () {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    setState(() => _invoiceItems.removeAt(index));
                                  }, padding: EdgeInsets.zero),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            Row(
                              children: [
                                Expanded(child: _buildCenteredInput(context: context, label: 'الكمية (كرتونة)', controller: item['qtyController'] as TextEditingController, focusNode: item['qtyFocus'] as FocusNode, keyboardType: TextInputType.number, textInputAction: TextInputAction.next, fieldCategory: 'qty')),
                                const SizedBox(width: 12),
                                Expanded(child: _buildCenteredInput(context: context, label: 'القطع بالكرتونة', controller: item['conversionFactorController'] as TextEditingController, focusNode: item['convFocus'] as FocusNode, keyboardType: TextInputType.number, textInputAction: TextInputAction.next, fieldCategory: 'qty')),
                              ],
                            ),

                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_rounded, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'إجمالي عدد القطع = $totalPieces قطعة',
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      _buildCenteredInput(context: context, label: 'سعر الشراء (للكرتونة)', controller: item['priceController'] as TextEditingController, focusNode: item['priceFocus'] as FocusNode, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next, fieldCategory: 'price'),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'تكلفة القطعة = ${_formatNumber(unitCost)} ج.م',
                                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('سعر البيع (للقطعة)', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w900, color: brandOrange)),
                                          InkWell(
                                            onTap: () => _showProfitMarginModal(targetItemIndex: index),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isCustom ? Colors.orange.shade700 : Colors.teal,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.percent_rounded, size: 10, color: Colors.white),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    item['itemMargin'] != null ? '${item['itemMargin']}' : '',
                                                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: item['sellingPriceController'] as TextEditingController,
                                        focusNode: item['sellFocus'] as FocusNode,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.done,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 16, color: Colors.black87),
                                        decoration: InputDecoration(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                          filled: true,
                                          fillColor: isCustom ? Colors.orange.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.08),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                        ),
                                        onFieldSubmitted: (_) {
                                          if (item['isNewProduct'] == true) {
                                            _addNewInlineProduct();
                                          } else {
                                            FocusManager.instance.primaryFocus?.unfocus();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('إجمالي قيمة الصنف:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text(
                                  '${_formatNumber(cartonPrice * qtyCarton)} ج.م',
                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: primaryNavy, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        _addNewInlineProduct();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryNavy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                      label: const Text('إضافة صنف جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_invoiceItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      // 🌟 إطار الخصم والضرائب باللون الكحلي المميز والمتناسق مع الهوية
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryNavy, width: 2),
                          boxShadow: [BoxShadow(color: primaryNavy.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))]
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: TextFormField(
                                      controller: _discountController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => _updateTotal(),
                                      decoration: InputDecoration(
                                          labelText: 'الخصم',
                                          prefixIcon: const Icon(Icons.discount_outlined, color: Colors.green),
                                          suffixIcon: IconButton(
                                              icon: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                                  child: Icon(_isDiscountPercent ? Icons.percent_rounded : Icons.payments_outlined, size: 16, color: Colors.black87)
                                              ),
                                              onPressed: () => setState(() => _isDiscountPercent = !_isDiscountPercent)
                                          ),
                                          filled: true, fillColor: bgSoftColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                                      )
                                  )
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: TextFormField(
                                      controller: _taxController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => _updateTotal(),
                                      decoration: InputDecoration(
                                          labelText: 'ضريبة (%)',
                                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.redAccent),
                                          suffixIcon: const Icon(Icons.percent_rounded, size: 16, color: Colors.grey),
                                          filled: true, fillColor: bgSoftColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                                      )
                                  )
                              ),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي قبل الخصم:', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold)), Text('${_formatNumber(_grossAmount)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'))]),
                          if (_discountAmount > 0) ...[
                            const SizedBox(height: 10),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الخصم:', style: TextStyle(fontFamily: 'Cairo', color: Colors.green, fontWeight: FontWeight.bold)), Text('-${_formatNumber(_discountAmount)} ج.م', style: const TextStyle(color: Colors.green, fontFamily: 'Cairo', fontWeight: FontWeight.bold))]),
                          ],
                          if (_taxAmount > 0) ...[
                            const SizedBox(height: 10),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الضريبة:', style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold)), Text('+${_formatNumber(_taxAmount)} ج.م', style: const TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold))]),
                          ],
                          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),

                          // 🌟 إطار الصافي للدفع باللون الكحلي المميز والبارز
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F8), // درجة كحلي فاتحة ومرعة للعين
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: primaryNavy, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryNavy.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'الصافي للدفع:',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: primaryNavy,
                                  ),
                                ),
                                Text(
                                  '${_formatNumber(_netAmount)} ج.م',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 24,
                                    color: brandOrange, // يفضل رقم الصافي بالبرتقالي عشان يشد العين
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _invoiceItems.isEmpty ? null : _saveInvoice,
                      style: ElevatedButton.styleFrom(backgroundColor: brandOrange, disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                      label: const Text('اعتماد الفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 300),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenteredInput({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    required String fieldCategory,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w900, color: primaryNavy)),
        const SizedBox(height: 6),
        Builder(
            builder: (iconContext) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 16, color: Colors.black87),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: bgSoftColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  suffixIcon: _buildSmartIcon(iconContext, controller, fieldCategory: fieldCategory),
                ),
              );
            }
        ),
      ],
    );
  }
}