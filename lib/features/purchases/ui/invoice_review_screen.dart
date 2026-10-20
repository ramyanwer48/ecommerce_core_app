import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../home/data/models/product_model.dart';
import '../services/purchase_service.dart';

class InvoiceReviewScreen extends StatefulWidget {
  final Map<String, dynamic>? invoiceData;

  const InvoiceReviewScreen({super.key, this.invoiceData});

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  final Color appPrimaryColor = const Color(0xFF0D1B2A);
  final Color appSecondaryColor = Colors.orange.shade600;
  final Color appBackgroundColor = const Color(0xFFF4F7FB);
  final Color alertRed = Colors.red.shade600;
  final Color successGreen = const Color(0xFF10B981);

  static const String _suppliersCollection = 'suppliers';

  late TextEditingController _supplierController;
  late TextEditingController _invoiceNoController;
  late TextEditingController _dateController;
  late DateTime _selectedDate;

  double? _currentGlobalMargin;

  List<Map<String, dynamic>> _extractedItems = [];
  Map<String, List<String>> _localTaxonomy = Map.from(MasterCatalogCategories.taxonomy);
  bool _isLoadingCategories = true;

  double _getSafeDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  int _getSafeInt(dynamic val) {
    if (val == null) return 1;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 1;
    return 1;
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

  void _updateTotal() => setState(() {});

  // 🌟 حسبة سعر البيع بناءً على سعر الكرتونة ومعامل التحويل ونسبة الربح
  void _calculateSellingPrice(Map<String, dynamic> item, double percentage) {
    double cartonPrice = double.tryParse((item['priceController'] as TextEditingController).text) ?? 0.0;
    double conversion = double.tryParse((item['conversionFactorController'] as TextEditingController).text) ?? 1.0;
    if (conversion <= 0) conversion = 1.0;

    double unitCost = cartonPrice / conversion;
    double sellingPrice = unitCost + (unitCost * (percentage / 100));
    (item['sellingPriceController'] as TextEditingController).text = _formatNumber(sellingPrice);
  }

  void _applyGlobalProfitMargin(double percentage) {
    setState(() {
      _currentGlobalMargin = percentage;
      for (var item in _extractedItems) {
        if (item['isCustomMargin'] != true) {
          item['itemMargin'] = percentage;
          _calculateSellingPrice(item, percentage);
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تطبيق نسبة $percentage% على الأصناف وتحديث أسعار البيع', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: successGreen),
    );
  }

  void _applyItemProfitMargin(int index, double percentage) {
    setState(() {
      var item = _extractedItems[index];
      item['itemMargin'] = percentage;
      if (_currentGlobalMargin != null && percentage == _currentGlobalMargin) {
        item['isCustomMargin'] = false;
      } else {
        item['isCustomMargin'] = true;
      }
      _calculateSellingPrice(item, percentage);
    });
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
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
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
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: appPrimaryColor),
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
                      backgroundColor: appBackgroundColor,
                      foregroundColor: appPrimaryColor,
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
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🌟 إجمالي قيمة الفاتورة المالية بناءً على الكرتونة وسعر الكرتونة
  double get _calculateGrandTotal {
    return _extractedItems.fold(0.0, (totalSum, item) {
      double cartonPrice = double.tryParse((item['priceController'] as TextEditingController).text) ?? 0.0;
      int qtyCarton = int.tryParse((item['qtyController'] as TextEditingController).text) ?? 0;
      return totalSum + (cartonPrice * qtyCarton);
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchCategoriesFromFirebase();

    final data = widget.invoiceData ?? {};
    String supplier = (data['partnerName'] ?? data['supplier'] ?? 'Unknown Supplier').toString();
    String invoiceNo = (data['invoiceNumber'] ?? data['invoice_no'] ?? 'INV-AI-001').toString();

    _supplierController = TextEditingController(text: supplier);
    _invoiceNoController = TextEditingController(text: invoiceNo);

    String? aiDate = data['invoiceDate'];
    if (aiDate != null && aiDate.isNotEmpty) {
      try {
        _selectedDate = DateTime.parse(aiDate);
      } catch (e) {
        _selectedDate = DateTime.now();
      }
    } else {
      _selectedDate = DateTime.now();
    }
    _dateController = TextEditingController(
      text: "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
    );

    if (data['items'] != null && data['items'] is List) {
      try {
        var rawItems = List<dynamic>.from(data['items']);
        _extractedItems = rawItems.map((rawItem) {
          if (rawItem == null) return _getDefaultItem();
          Map<String, dynamic> item = Map<String, dynamic>.from(rawItem as Map);

          String aiMainCat = (item['mainCategory'] ?? 'Uncategorized').toString();
          String aiSubCat = (item['subCategory'] ?? 'Uncategorized').toString();

          if (!_localTaxonomy.containsKey(aiMainCat)) {
            aiMainCat = _localTaxonomy.keys.isNotEmpty ? _localTaxonomy.keys.first : 'General';
          }
          if (!(_localTaxonomy[aiMainCat]?.contains(aiSubCat) ?? false)) {
            aiSubCat = _localTaxonomy[aiMainCat]?.first ?? 'General';
          }

          double parsedCost = _getSafeDouble(item['unitPrice'] ?? item['price']);
          int parsedQty = _getSafeInt(item['quantity'] ?? item['qty']);

          return {
            '_id': UniqueKey().toString(),
            'rawAiName': (item['productName'] ?? item['name'] ?? 'Unknown Item').toString(),
            'mappedId': null,
            'mappedName': (item['productName'] ?? item['name'] ?? 'Unknown Item').toString(),
            'isNewProduct': true,
            'isAutoMatched': false,
            'mainCategory': aiMainCat,
            'subCategory': aiSubCat,
            'qtyController': TextEditingController(text: parsedQty.toString()),
            'conversionFactorController': TextEditingController(text: '1'),
            'priceController': TextEditingController(text: _formatNumber(parsedCost)),
            'sellingPriceController': TextEditingController(text: '0'),
            'itemMargin': null,
            'isCustomMargin': false,
            'imageUrls': <String>[],
          };
        }).toList();
      } catch (e) {
        _extractedItems = [_getDefaultItem()];
      }
    } else {
      _extractedItems = [_getDefaultItem()];
    }

    _autoMatchProductsWithInventory();
  }

  Future<void> _autoMatchProductsWithInventory() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('products').get();
      var existingProducts = snapshot.docs;

      if (!mounted) return;

      setState(() {
        for (int i = 0; i < _extractedItems.length; i++) {
          String aiName = _extractedItems[i]['rawAiName'].toString().toLowerCase().trim();

          for (var doc in existingProducts) {
            var data = doc.data();
            String dbName = (data['name'] ?? '').toString().toLowerCase().trim();

            if (aiName == dbName) {
              _extractedItems[i]['isNewProduct'] = false;
              _extractedItems[i]['isAutoMatched'] = true;
              _extractedItems[i]['mappedId'] = doc.id;
              _extractedItems[i]['mappedName'] = data['name'];

              String dbMain = data['category'] ?? _extractedItems[i]['mainCategory'];
              String dbSub = data['subCategory'] ?? _extractedItems[i]['subCategory'];
              _extractedItems[i]['mainCategory'] = dbMain;
              _extractedItems[i]['subCategory'] = dbSub;

              if (data['price'] != null) {
                (_extractedItems[i]['sellingPriceController'] as TextEditingController).text = _formatNumber(data['price']);
              }
              break;
            }
          }
        }
      });
    } catch (e) {
      debugPrint("Auto-match error: $e");
    }
  }

  Future<void> _fetchCategoriesFromFirebase() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('categories').get();
      setState(() {
        for (var doc in snapshot.docs) {
          var data = doc.data();
          String mainCat = data['name'] ?? doc.id;
          List<String> subCats = [];
          if (data['subCategories'] != null) subCats = List<String>.from(data['subCategories']);
          if (subCats.isEmpty) subCats = ['General'];

          if (_localTaxonomy.containsKey(mainCat)) {
            for (String sub in subCats) {
              if (!_localTaxonomy[mainCat]!.contains(sub)) _localTaxonomy[mainCat]!.add(sub);
            }
          } else {
            _localTaxonomy[mainCat] = subCats;
          }
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() => _isLoadingCategories = false);
    }
  }

  void _showSupplierPickerModal() {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            Text('اختر من الموردين المسجلين', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: appPrimaryColor)),
            const Divider(),
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection(_suppliersCollection).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: appSecondaryColor));
                  var docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('لا يوجد موردون مسجلون حالياً', style: TextStyle(fontFamily: 'Cairo')),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      String sName = (data['name'] ?? '').toString();
                      return ListTile(
                        leading: Icon(Icons.storefront, color: appSecondaryColor),
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

  Map<String, dynamic> _getDefaultItem() {
    return {
      '_id': UniqueKey().toString(),
      'rawAiName': 'New Item',
      'mappedId': null,
      'mappedName': 'New Item',
      'isNewProduct': true,
      'isAutoMatched': false,
      'mainCategory': _localTaxonomy.keys.isNotEmpty ? _localTaxonomy.keys.first : 'General',
      'subCategory': _localTaxonomy.values.isNotEmpty ? _localTaxonomy.values.first.first : 'General',
      'qtyController': TextEditingController(text: '1'),
      'conversionFactorController': TextEditingController(text: '1'),
      'priceController': TextEditingController(text: '0'),
      'sellingPriceController': TextEditingController(text: '0'),
      'itemMargin': null,
      'isCustomMargin': false,
      'imageUrls': <String>[],
    };
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceNoController.dispose();
    _dateController.dispose();
    for (var item in _extractedItems) {
      (item['qtyController'] as TextEditingController?)?.dispose();
      (item['conversionFactorController'] as TextEditingController?)?.dispose();
      (item['priceController'] as TextEditingController?)?.dispose();
      (item['sellingPriceController'] as TextEditingController?)?.dispose();
    }
    super.dispose();
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
            colorScheme: ColorScheme.light(primary: appPrimaryColor, onPrimary: Colors.white, onSurface: Colors.black),
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

  bool get _isAllItemsReady {
    if (_extractedItems.isEmpty) return false;
    return _extractedItems.every((item) =>
    item['mappedName'] != null &&
        item['mappedName'].toString().isNotEmpty &&
        item['mainCategory'] != null &&
        item['subCategory'] != null);
  }

  void _addNewMainCategory(Map<String, dynamic> currentItem) {
    FocusManager.instance.primaryFocus?.unfocus();
    TextEditingController catController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              Text('تصنيف أساسي جديد', style: TextStyle(fontFamily: 'Cairo', color: appPrimaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              TextField(
                controller: catController,
                autofocus: true,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'اكتب اسم التصنيف هنا...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: appSecondaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () async {
                    String newCat = catController.text.trim();
                    if (newCat.isNotEmpty) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(ctx);
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (mounted) {
                          setState(() {
                            _localTaxonomy[newCat] = ['General'];
                            currentItem['mainCategory'] = newCat;
                            currentItem['subCategory'] = 'General';
                          });
                        }
                      });
                      try {
                        await FirebaseFirestore.instance.collection('categories').doc(newCat).set({'name': newCat, 'subCategories': ['General']}, SetOptions(merge: true));
                      } catch (e) {
                        debugPrint("خطأ: $e");
                      }
                    }
                  },
                  child: const Text('حفظ سريع', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _addNewSubCategory(String mainCategory, Map<String, dynamic> currentItem) {
    FocusManager.instance.primaryFocus?.unfocus();
    TextEditingController catController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              Text('فرعي جديد لـ ($mainCategory)', style: TextStyle(fontFamily: 'Cairo', color: appPrimaryColor, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextField(
                controller: catController,
                autofocus: true,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'اكتب اسم التصنيف هنا...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: appSecondaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () async {
                    String newSubCat = catController.text.trim();
                    if (newSubCat.isNotEmpty) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(ctx);

                      // 1. التحديث المحلي الفوري عشان تظهر في الواجهة لحظياً
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (mounted) {
                          setState(() {
                            if (_localTaxonomy[mainCategory] != null) {
                              if (!_localTaxonomy[mainCategory]!.contains(newSubCat)) {
                                _localTaxonomy[mainCategory]!.add(newSubCat);
                              }
                            } else {
                              _localTaxonomy[mainCategory] = [newSubCat];
                            }
                            currentItem['subCategory'] = newSubCat;
                          });
                        }
                      });

                      // 2. الحفظ الأصلي المطابق لكودك القديم في فايربيز
                      try {
                        await FirebaseFirestore.instance.collection('categories').doc(mainCategory).update({
                          'subCategories': FieldValue.arrayUnion([newSubCat])
                        });
                      } catch (e) {
                        await FirebaseFirestore.instance.collection('categories').doc(mainCategory).set({
                          'name': mainCategory,
                          'subCategories': [newSubCat]
                        }, SetOptions(merge: true));
                      }
                    }
                  },
                  child: const Text('حفظ سريع', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showCategorySelector(Map<String, dynamic> item, bool isMain) {
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // 🌟 جلب الخيارات مباشرة وتحديثها لحظياً
          List<String> options = isMain ? _localTaxonomy.keys.toList() : (_localTaxonomy[item['mainCategory']] ?? []);

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                Text(isMain ? 'اختر التصنيف الأساسي' : 'اختر التصنيف الفرعي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: appPrimaryColor)),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: Icon(isMain ? Icons.category : Icons.account_tree, color: appSecondaryColor, size: 20),
                        title: Text(options[index], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.pop(ctx);
                          Future.delayed(const Duration(milliseconds: 150), () {
                            if (mounted) {
                              setState(() {
                                if (isMain) {
                                  item['mainCategory'] = options[index];
                                  item['subCategory'] = _localTaxonomy[options[index]]?.isNotEmpty == true ? _localTaxonomy[options[index]]!.first : 'General';
                                } else {
                                  item['subCategory'] = options[index];
                                }
                              });
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _approveAndSaveInvoice() async {
    if (_extractedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('الفاتورة فارغة!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: alertRed));
      return;
    }
    if (!_isAllItemsReady) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('تأكد من إكمال بيانات التصنيف لجميع الأصناف!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: alertRed));
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.heavyImpact();
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => Center(child: CircularProgressIndicator(color: appSecondaryColor)));

    try {
      // 🌟 تجهيز البيانات للخدمة بالاعتماد على قيم الـ Controllers
      List<Map<String, dynamic>> finalItemsToSave = _extractedItems.map((item) {
        return {
          'mappedName': item['mappedName'],
          'rawAiName': item['rawAiName'],
          'mappedId': item['mappedId'],
          'isNewProduct': item['isNewProduct'],
          'mainCategory': item['mainCategory'],
          'subCategory': item['subCategory'],
          'conversionFactor': int.tryParse((item['conversionFactorController'] as TextEditingController).text) ?? 1,
          'imageUrls': item['imageUrls'] ?? <String>[],
          'qty': int.tryParse((item['qtyController'] as TextEditingController).text) ?? 1,
          'price': double.tryParse((item['priceController'] as TextEditingController).text) ?? 0.0,
          'sellingPrice': double.tryParse((item['sellingPriceController'] as TextEditingController).text) ?? 0.0,
        };
      }).toList();

      await PurchaseService().processApprovedInvoice(
        supplierName: _supplierController.text.trim(),
        invoiceNumber: _invoiceNoController.text.trim(),
        invoiceDate: _selectedDate,
        items: finalItemsToSave,
        source: 'ai',
      );

      if (mounted) Navigator.pop(context);
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: successGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.check_circle_rounded, color: successGreen, size: 60),
                  ),
                  const SizedBox(height: 20),
                  Text('تم ترحيل الفاتورة بنجاح!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: appPrimaryColor), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text('تم تحديث المخزون، وتحديث حساب المورد، وإنشاء القيد المحاسبي بنجاح.', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black87), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appSecondaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.pop(dialogContext);
                        context.pop();
                      },
                      child: const Text('العودة للسجل', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الترحيل: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: alertRed));
    }
  }

  void _addNewItemManually() {
    setState(() => _extractedItems.add(_getDefaultItem()));
    HapticFeedback.lightImpact();
  }

  void _removeItem(int index) {
    setState(() => _extractedItems.removeAt(index));
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCategories) {
      return Scaffold(backgroundColor: appBackgroundColor, body: Center(child: CircularProgressIndicator(color: appSecondaryColor)));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: appBackgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('مراجعة وتسكين الفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            centerTitle: true,
            backgroundColor: appPrimaryColor,
            elevation: 0,
            actions: [
              if (Navigator.canPop(context))
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              if (Navigator.canPop(context)) const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  shadowColor: appPrimaryColor.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('بيانات الفاتورة والمورد', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: appSecondaryColor)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _supplierController,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          minLines: 1,
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'اسم المورد',
                            labelStyle: TextStyle(color: appSecondaryColor, fontSize: 12),
                            suffixIcon: IconButton(
                              tooltip: 'اختر من الموردين المسجلين',
                              icon: Icon(Icons.storefront, color: appSecondaryColor, size: 20),
                              onPressed: _showSupplierPickerModal,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _invoiceNoController,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'رقم الفاتورة',
                                  labelStyle: TextStyle(color: appSecondaryColor, fontSize: 13),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _dateController,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                                readOnly: true,
                                onTap: () => _selectDate(context),
                                decoration: InputDecoration(
                                  labelText: 'تاريخ الفاتورة',
                                  labelStyle: TextStyle(color: appSecondaryColor, fontSize: 13),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                  suffixIcon: Icon(Icons.calendar_month, color: appSecondaryColor, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showProfitMarginModal(),
                            icon: const Icon(Icons.percent_rounded, size: 18),
                            label: Text(
                              _currentGlobalMargin == null
                                  ? 'نسبة الربح العامة للفاتورة (اضغط للتطبيق)'
                                  : 'نسبة الربح المطبقة: $_currentGlobalMargin% (اضغط للتغيير)',
                              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _currentGlobalMargin == null ? Colors.teal : Colors.teal.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.teal.shade200, width: 1.5),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _extractedItems.length,
                  itemBuilder: (context, index) {
                    final item = _extractedItems[index];
                    bool isNew = item['isNewProduct'];
                    bool isAutoMatched = item['isAutoMatched'] ?? false;
                    bool isCustom = item['isCustomMargin'] == true;
                    bool isItemComplete = item['mappedName'] != null && item['mappedName'].toString().isNotEmpty && item['mainCategory'] != null && item['subCategory'] != null;
                    Color cardBorderColor = isItemComplete ? (isNew ? appSecondaryColor : successGreen) : alertRed;

                    // 🌟 حسابات الكرتونة والقطع الإجمالية
                    int qtyCarton = int.tryParse((item['qtyController'] as TextEditingController).text) ?? 0;
                    int convFactor = int.tryParse((item['conversionFactorController'] as TextEditingController).text) ?? 1;
                    if (convFactor <= 0) convFactor = 1;
                    int totalPieces = qtyCarton * convFactor;

                    double cartonPrice = double.tryParse((item['priceController'] as TextEditingController).text) ?? 0.0;
                    double unitCost = cartonPrice / convFactor;

                    return Card(
                      key: ValueKey(item['_id']),
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cardBorderColor, width: 2)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(width: 32, height: 32, decoration: BoxDecoration(color: appPrimaryColor, shape: BoxShape.circle), child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)))),
                                    const SizedBox(width: 8),
                                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () { FocusManager.instance.primaryFocus?.unfocus(); _removeItem(index); }),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: (isAutoMatched || !isNew) ? successGreen.withValues(alpha: 0.15) : appSecondaryColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(isAutoMatched ? Icons.auto_awesome : (isNew ? Icons.fiber_new_rounded : Icons.check_circle), size: 16, color: (isAutoMatched || !isNew) ? successGreen : appSecondaryColor),
                                      const SizedBox(width: 6),
                                      Text(isAutoMatched ? 'تم التعرف تلقائياً' : (isNew ? 'صنف جديد' : 'مربوط بصنف مسجل'), style: TextStyle(fontSize: 12, color: (isAutoMatched || !isNew) ? successGreen : appSecondaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              initialValue: item['mappedName'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'اسم الصنف',
                                labelStyle: TextStyle(color: appSecondaryColor, fontSize: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                fillColor: isNew ? Colors.white : Colors.grey.shade100,
                                filled: true,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              ),
                              readOnly: !isNew,
                              onChanged: (val) => setState(() => item['mappedName'] = val),
                            ),
                            const SizedBox(height: 12),

                            // 🌟 الكمية (كرتونة) والقطع بالكرتونة مثل الشاشة اليدوية تماماً
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: item['qtyController'] as TextEditingController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
                                    decoration: InputDecoration(
                                      labelText: 'الكمية (كرتونة)',
                                      labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Cairo'),
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                    ),
                                    onChanged: (val) => _updateTotal(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: item['conversionFactorController'] as TextEditingController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      labelText: 'القطع بالكرتونة',
                                      labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Cairo'),
                                      hintText: 'مثال: 12',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                    ),
                                    onChanged: (val) {
                                      double? currentMargin = item['itemMargin'] as double? ?? _currentGlobalMargin;
                                      if (currentMargin != null) {
                                        _calculateSellingPrice(item, currentMargin);
                                      }
                                      _updateTotal();
                                    },
                                  ),
                                ),
                              ],
                            ),

                            // 🌟 عرض إجمالي عدد القطع
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

                            // 🌟 سعر الشراء (للكرتونة) وسعر البيع (للقطعة) مع تكلفة القطعة
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: item['priceController'] as TextEditingController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        decoration: InputDecoration(
                                          labelText: 'سعر الشراء (للكرتونة)',
                                          labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Cairo'),
                                          isDense: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                        ),
                                        onChanged: (val) {
                                          _updateTotal();
                                          double? currentMargin = item['itemMargin'] as double? ?? _currentGlobalMargin;
                                          if (currentMargin != null) {
                                            _calculateSellingPrice(item, currentMargin);
                                          }
                                        },
                                      ),
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
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('سعر البيع (للقطعة)', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w900, color: appSecondaryColor)),
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
                                                    item['itemMargin'] != null ? '${item['itemMargin']}' : 'نسبة',
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
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 16, color: Colors.black87),
                                        decoration: InputDecoration(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                          filled: true,
                                          fillColor: isCustom ? Colors.orange.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.08),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                        ),
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
                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: appPrimaryColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: appPrimaryColor.withValues(alpha: 0.02), border: Border.all(color: appSecondaryColor.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('التصنيف المحاسبي والمخزني:', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: appSecondaryColor)),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: !isNew ? null : () => _showCategorySelector(item, true),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8), color: isNew ? Colors.white : Colors.grey.shade100),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(child: Text(item['mainCategory'] ?? 'التصنيف الأساسي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: isNew ? Colors.black87 : Colors.grey), overflow: TextOverflow.ellipsis)),
                                                const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isNew) ...[
                                        const SizedBox(width: 8),
                                        SizedBox(width: 40, child: IconButton(padding: EdgeInsets.zero, icon: Icon(Icons.add_circle, color: appSecondaryColor, size: 28), onPressed: () => _addNewMainCategory(item), tooltip: 'إضافة تصنيف')),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: !isNew ? null : () => _showCategorySelector(item, false),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8), color: isNew ? Colors.white : Colors.grey.shade100),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(child: Text(item['subCategory'] ?? 'التصنيف الفرعي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: isNew ? Colors.black87 : Colors.grey), overflow: TextOverflow.ellipsis)),
                                                const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isNew) ...[
                                        const SizedBox(width: 8),
                                        SizedBox(width: 40, child: IconButton(padding: EdgeInsets.zero, icon: Icon(Icons.add_circle, color: appSecondaryColor, size: 28), onPressed: () => _addNewSubCategory(item['mainCategory'], item), tooltip: 'إضافة تصنيف')),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      _addNewItemManually();
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: appPrimaryColor, side: BorderSide(color: appPrimaryColor, width: 2), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة صنف جديد للفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),

                Container(
                  margin: const EdgeInsets.only(bottom: 40),
                  child: ElevatedButton.icon(
                    onPressed: _approveAndSaveInvoice,
                    style: ElevatedButton.styleFrom(backgroundColor: appSecondaryColor, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const Icon(Icons.save_alt, color: Colors.white),
                    label: Text('تأكيد وحفظ الفاتورة (${_formatNumber(_calculateGrandTotal)} EGP)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}