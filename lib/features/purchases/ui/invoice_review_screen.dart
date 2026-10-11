import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../home/data/models/product_model.dart';
import '../services/purchase_service.dart';
import '../../admin/ui/widgets/google_image_picker_dialog.dart';

class InvoiceReviewScreen extends StatefulWidget {
  final Map<String, dynamic>? invoiceData;

  const InvoiceReviewScreen({super.key, this.invoiceData});

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  final Color appPrimaryColor = const Color(0xFF0B1E3F);
  final Color appSecondaryColor = const Color(0xFFFF9F0A);
  final Color appBackgroundColor = const Color(0xFFF4F6F9);
  final Color alertRed = Colors.red.shade600;
  final Color successGreen = const Color(0xFF10B981);

  late TextEditingController _supplierController;
  late TextEditingController _invoiceNoController;
  late TextEditingController _dateController;
  late DateTime _selectedDate;

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

          return {
            '_id': UniqueKey().toString(),
            'rawAiName': (item['productName'] ?? item['name'] ?? 'Unknown Item').toString(),
            'mappedId': null,
            'mappedName': (item['productName'] ?? item['name'] ?? 'Unknown Item').toString(),
            'isNewProduct': true,
            'isAutoMatched': false, // 👈 فلاج جديد لمعرفة هل تم التعرف عليه تلقائياً
            'mainCategory': aiMainCat,
            'subCategory': aiSubCat,
            'qty': _getSafeInt(item['quantity'] ?? item['qty']),
            'price': parsedCost,
            'sellingPrice': 0.0,
            'conversionFactor': 1,
            'imageUrls': <String>[],
          };
        }).toList();
      } catch (e) {
        _extractedItems = [_getDefaultItem()];
      }
    } else {
      _extractedItems = [_getDefaultItem()];
    }

    // 🚀 تشغيل محرك المطابقة التلقائية فوراً
    _autoMatchProductsWithInventory();
  }

  // 🧠 دالة السحر: المطابقة التلقائية مع المخزون
  Future<void> _autoMatchProductsWithInventory() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('products').get();
      var existingProducts = snapshot.docs;

      if (!mounted) return;

      setState(() {
        for (int i = 0; i < _extractedItems.length; i++) {
          // تنظيف اسم الذكاء الاصطناعي للبحث الدقيق
          String aiName = _extractedItems[i]['rawAiName'].toString().toLowerCase().trim();

          for (var doc in existingProducts) {
            var data = doc.data();
            String dbName = (data['name'] ?? '').toString().toLowerCase().trim();

            // مطابقة تامة أو لو اسم الداتابيز بيحتوي على اسم الذكاء الاصطناعي (أو العكس)
            if (aiName == dbName || dbName == aiName) {
              _extractedItems[i]['isNewProduct'] = false;
              _extractedItems[i]['isAutoMatched'] = true; // 👈 تفعيل علامة الذكاء
              _extractedItems[i]['mappedId'] = doc.id;
              _extractedItems[i]['mappedName'] = data['name'];

              // سحب التصنيف وسعر البيع من المخزون وتعبئته أوتوماتيكياً
              String dbMain = data['category'] ?? _extractedItems[i]['mainCategory'];
              String dbSub = data['subCategory'] ?? _extractedItems[i]['subCategory'];
              _extractedItems[i]['mainCategory'] = dbMain;
              _extractedItems[i]['subCategory'] = dbSub;

              if (data['price'] != null) {
                _extractedItems[i]['sellingPrice'] = _getSafeDouble(data['price']);
              }
              break; // تم إيجاد الصنف، انتقل للصنف التالي في الفاتورة
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
      'qty': 1,
      'price': 0.0,
      'sellingPrice': 0.0,
      'conversionFactor': 1,
      'imageUrls': <String>[],
    };
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceNoController.dispose();
    _dateController.dispose();
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

  double get _calculateGrandTotal {
    double total = 0;
    for (var item in _extractedItems) {
      total += (_getSafeDouble(item['qty']) * _getSafeDouble(item['price']));
    }
    return total;
  }

  bool get _isAllItemsReady {
    if (_extractedItems.isEmpty) return false;
    return _extractedItems.every((item) =>
    item['mappedName'] != null && item['mappedName'].toString().isNotEmpty &&
        item['mainCategory'] != null && item['subCategory'] != null
    );
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
                controller: catController, autofocus: true,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                    hintText: 'اكتب اسم التصنيف هنا...',
                    isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appSecondaryColor, width: 2))
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
                      try { await FirebaseFirestore.instance.collection('categories').doc(newCat).set({'name': newCat, 'subCategories': ['General']}, SetOptions(merge: true)); } catch (e) { debugPrint("خطأ: $e"); }
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
                controller: catController, autofocus: true,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                    hintText: 'اكتب اسم التصنيف هنا...',
                    isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appSecondaryColor, width: 2))
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
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (mounted) {
                          setState(() {
                            if (_localTaxonomy[mainCategory] != null) { _localTaxonomy[mainCategory]!.add(newSubCat); }
                            else { _localTaxonomy[mainCategory] = [newSubCat]; }
                            currentItem['subCategory'] = newSubCat;
                          });
                        }
                      });
                      try {
                        await FirebaseFirestore.instance.collection('categories').doc(mainCategory).update({'subCategories': FieldValue.arrayUnion([newSubCat])});
                      } catch (e) {
                        await FirebaseFirestore.instance.collection('categories').doc(mainCategory).set({'name': mainCategory, 'subCategories': [newSubCat]}, SetOptions(merge: true));
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
    List<String> options = isMain ? _localTaxonomy.keys.toList() : (_localTaxonomy[item['mainCategory']] ?? []);
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
                        if(mounted){
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
      ),
    );
  }

  Future<void> _pickFromGoogleSearch(int index, String productName) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final List<String>? selectedImageUrls = await showDialog<List<String>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => GoogleImagePickerDialog(productName: productName)
    );

    FocusManager.instance.primaryFocus?.unfocus();

    if (selectedImageUrls != null && selectedImageUrls.isNotEmpty && mounted) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _extractedItems[index]['imageUrls'] = selectedImageUrls;
          });
          FocusManager.instance.primaryFocus?.unfocus();
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم إرفاق صور جوجل للمنتج!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green)
          );
        }
      });
    }
  }

  void _showImagePickerOptions(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    String productName = _extractedItems[index]['mappedName'] ?? 'منتج جديد';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إضافة صورة لـ: $productName', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: appPrimaryColor)),
            const Divider(thickness: 2, height: 30),
            ListTile(
              leading: Icon(Icons.travel_explore, color: appSecondaryColor, size: 30),
              title: const Text('بحث من جوجل 🌐', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(ctx);
                Future.delayed(const Duration(milliseconds: 150), () {
                  _pickFromGoogleSearch(index, productName);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProductSearchModal(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    String currentQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('اختر الصنف من المخزن لإضافة الدفعة', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: appSecondaryColor)),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(labelText: 'ابحث عن المنتج...', prefixIcon: Icon(Icons.search, color: appSecondaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    onChanged: (val) { setModalState(() { currentQuery = val.toLowerCase(); }); },
                  ),
                  const Divider(height: 30, thickness: 2),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('products').limit(50).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: appSecondaryColor));
                        var docs = snapshot.data!.docs.where((doc) {
                          String name = (doc.data() as Map<String, dynamic>)['name']?.toString().toLowerCase() ?? '';
                          return name.contains(currentQuery);
                        }).toList();
                        if (docs.isEmpty) return const Center(child: Text('هذا الصنف غير مسجل.', style: TextStyle(fontFamily: 'Cairo')));
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            var data = docs[i].data() as Map<String, dynamic>;
                            return Card(
                              child: ListTile(
                                leading: Icon(Icons.inventory_2, color: appSecondaryColor),
                                title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${data['category']} - ${data['subCategory']} | رصيد: ${data['stockQuantity'] ?? 0}'),
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  Navigator.pop(ctx);
                                  Future.delayed(const Duration(milliseconds: 150), () {
                                    if(mounted){
                                      setState(() {
                                        _extractedItems[index]['isNewProduct'] = false;
                                        _extractedItems[index]['isAutoMatched'] = false; // ربط يدوي
                                        _extractedItems[index]['mappedId'] = docs[i].id;
                                        _extractedItems[index]['mappedName'] = data['name'];
                                        String dbMain = data['category'] ?? _localTaxonomy.keys.first;
                                        String dbSub = data['subCategory'] ?? 'General';
                                        if (!_localTaxonomy.containsKey(dbMain)) { _localTaxonomy[dbMain] = [dbSub]; }
                                        else if (!_localTaxonomy[dbMain]!.contains(dbSub)) { _localTaxonomy[dbMain]!.add(dbSub); }
                                        _extractedItems[index]['mainCategory'] = dbMain;
                                        _extractedItems[index]['subCategory'] = dbSub;
                                        if (data['price'] != null) { _extractedItems[index]['sellingPrice'] = _getSafeDouble(data['price']); }
                                      });
                                    }
                                  });
                                },
                              ),
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

  Future<void> _approveAndSaveInvoice() async {
    if (_extractedItems.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('الفاتورة فارغة!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: alertRed)); return; }
    if (!_isAllItemsReady) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('تأكد من إكمال بيانات التصنيف لجميع الأصناف!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: alertRed)); return; }

    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.heavyImpact();
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => Center(child: CircularProgressIndicator(color: appSecondaryColor)));

    try {
      await PurchaseService().processApprovedInvoice(
        supplierName: _supplierController.text.trim(),
        invoiceNumber: _invoiceNoController.text.trim(),
        invoiceDate: _selectedDate,
        items: _extractedItems,
      );

      if (mounted) Navigator.pop(context);
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('تم ترحيل الفاتورة بنجاح! 🎉', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: appSecondaryColor), textAlign: TextAlign.center),
            content: const Text('تم تحديث المخزون، إنشاء القيد المحاسبي، وأرشفة الفاتورة كمسودة.', style: TextStyle(fontFamily: 'Cairo'), textAlign: TextAlign.center),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: appSecondaryColor),
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.pop(dialogContext);
                  context.pop();
                },
                child: const Text('العودة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الترحيل: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: alertRed));
    }
  }

  void _addNewItemManually() { setState(() => _extractedItems.add(_getDefaultItem())); HapticFeedback.lightImpact(); }
  void _removeItem(int index) { setState(() => _extractedItems.removeAt(index)); HapticFeedback.lightImpact(); }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCategories) { return Scaffold(backgroundColor: appBackgroundColor, body: Center(child: CircularProgressIndicator(color: appSecondaryColor))); }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: appBackgroundColor,
          appBar: AppBar(title: const Text('مراجعة وتسكين الفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)), centerTitle: true, backgroundColor: appPrimaryColor, foregroundColor: Colors.white, elevation: 0),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4, shadowColor: appPrimaryColor.withOpacity(0.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              isDense: true
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _invoiceNoController, textAlign: TextAlign.center,
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                                decoration: InputDecoration(
                                    labelText: 'رقم الفاتورة', labelStyle: TextStyle(color: appSecondaryColor, fontSize: 13),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    isDense: true
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _dateController, textAlign: TextAlign.center,
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                                readOnly: true,
                                onTap: () => _selectDate(context),
                                decoration: InputDecoration(
                                  labelText: 'تاريخ الفاتورة', labelStyle: TextStyle(color: appSecondaryColor, fontSize: 13),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _extractedItems.length,
                  itemBuilder: (context, index) {
                    final item = _extractedItems[index];
                    bool isNew = item['isNewProduct'];
                    bool isAutoMatched = item['isAutoMatched'] ?? false;
                    bool isItemComplete = item['mappedName'] != null && item['mappedName'].toString().isNotEmpty && item['mainCategory'] != null && item['subCategory'] != null;
                    Color cardBorderColor = isItemComplete ? (isNew ? appSecondaryColor : successGreen) : alertRed;
                    List<String> images = item['imageUrls'] ?? [];

                    return Card(
                      key: ValueKey(item['_id']),
                      color: Colors.white, margin: const EdgeInsets.only(bottom: 16), elevation: 3,
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
                                if (isNew)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: appSecondaryColor, side: BorderSide(color: appSecondaryColor, width: 1.5), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), minimumSize: const Size(0, 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                    icon: const Icon(Icons.link, size: 16), label: const Text('صنف مسجل', style: TextStyle(fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                    onPressed: () => _showProductSearchModal(index),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: successGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(isAutoMatched ? Icons.auto_awesome : Icons.check_circle, size: 16, color: successGreen), const SizedBox(width: 6),
                                        // 👈 التنبيه الاحترافي
                                        Text(isAutoMatched ? 'تم التعرف تلقائياً 🤖' : 'مربوط بصنف مسجل', style: TextStyle(fontSize: 12, color: successGreen, fontWeight: FontWeight.bold, fontFamily: 'Cairo')), const SizedBox(width: 8),
                                        InkWell(onTap: () { FocusManager.instance.primaryFocus?.unfocus(); setState(() { item['isNewProduct'] = true; item['isAutoMatched'] = false; item['mappedId'] = null; item['mappedName'] = item['rawAiName']; }); }, child: const Icon(Icons.close, size: 18, color: Colors.red))
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: isNew ? () => _showImagePickerOptions(index) : null,
                                  child: Container(
                                    width: 70, height: 70, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: isNew ? appSecondaryColor : Colors.grey.shade300, width: 1.5)),
                                    child: images.isNotEmpty
                                        ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(images.first, fit: BoxFit.cover))
                                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_search, color: isNew ? appSecondaryColor : Colors.grey, size: 24), const SizedBox(height: 4), Text('صورة', style: TextStyle(fontSize: 10, color: isNew ? appSecondaryColor : Colors.grey, fontFamily: 'Cairo'))]),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['mappedName'], textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    decoration: InputDecoration(
                                      labelText: isNew ? 'اسم الصنف الجديد' : 'الصنف (مقفل)',
                                      labelStyle: TextStyle(color: appSecondaryColor, fontSize: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                      fillColor: isNew ? Colors.white : Colors.grey.shade100,
                                      filled: true,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    ),
                                    readOnly: !isNew, onChanged: (val) => setState(() => item['mappedName'] = val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['price'].toString(), keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    decoration: InputDecoration(labelText: 'سعر الشراء', prefixText: 'EGP ', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2))),
                                    onChanged: (val) => setState(() => item['price'] = double.tryParse(val) ?? 0.0),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['sellingPrice'].toString(), keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: appSecondaryColor),
                                    decoration: InputDecoration(labelText: 'سعر البيع المقترح', prefixText: 'EGP ', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2))),
                                    onChanged: (val) => setState(() => item['sellingPrice'] = double.tryParse(val) ?? 0.0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['qty'].toString(), keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
                                    decoration: InputDecoration(
                                        labelText: 'الكمية الواردة',
                                        labelStyle: const TextStyle(fontSize: 12),
                                        isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2))
                                    ),
                                    onChanged: (val) => setState(() => item['qty'] = int.tryParse(val) ?? 1),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['conversionFactor'].toString(), keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                        labelText: 'الكرتونة (كام قطعة؟)',
                                        labelStyle: const TextStyle(fontSize: 12),
                                        hintText: 'مثال: 12',
                                        isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2))
                                    ),
                                    onChanged: (val) => item['conversionFactor'] = int.tryParse(val) ?? 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Container(
                              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: appPrimaryColor.withOpacity(0.02), border: Border.all(color: appSecondaryColor.withOpacity(0.4)), borderRadius: BorderRadius.circular(10)),
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
                    onPressed: () { FocusManager.instance.primaryFocus?.unfocus(); _addNewItemManually(); },
                    style: OutlinedButton.styleFrom(foregroundColor: appPrimaryColor, side: BorderSide(color: appPrimaryColor, width: 2), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.add), label: const Text('إضافة صنف جديد للفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),

                Container(
                  margin: const EdgeInsets.only(bottom: 40),
                  child: ElevatedButton.icon(
                    onPressed: _approveAndSaveInvoice,
                    style: ElevatedButton.styleFrom(backgroundColor: appSecondaryColor, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const Icon(Icons.save_alt, color: Colors.white),
                    label: Text('تأكيد وحفظ الفاتورة (${_calculateGrandTotal.toStringAsFixed(2)} EGP)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
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