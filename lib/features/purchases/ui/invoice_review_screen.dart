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
  final Color appPrimaryColor = const Color(0xFF0B1E3F);
  final Color appSecondaryColor = const Color(0xFFFF9F0A);
  final Color appBackgroundColor = const Color(0xFFF4F6F9);
  final Color alertRed = Colors.red.shade600;
  final Color successGreen = const Color(0xFF10B981);

  late TextEditingController _supplierController;
  late TextEditingController _invoiceNoController;

  List<Map<String, dynamic>> _extractedItems = [];
  // 👈 دمجنا القائمة الثابتة الممتازة كقاعدة أساسية
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
    // جلب أي أقسام إضافية من فايربيز ودمجها مع القائمة الثابتة
    _fetchCategoriesFromFirebase();

    final data = widget.invoiceData ?? {};
    String supplier = (data['partnerName'] ?? data['supplier'] ?? 'Unknown Supplier').toString();
    String invoiceNo = (data['invoiceNumber'] ?? data['invoice_no'] ?? 'INV-AI-001').toString();

    _supplierController = TextEditingController(text: supplier);
    _invoiceNoController = TextEditingController(text: invoiceNo);

    if (data['items'] != null && data['items'] is List) {
      try {
        var rawItems = List<dynamic>.from(data['items']);
        _extractedItems = rawItems.map((rawItem) {
          if (rawItem == null) return _getDefaultItem();
          Map<String, dynamic> item = Map<String, dynamic>.from(rawItem as Map);

          // 👈 إعادة تفعيل الذكاء الاصطناعي لاختيار التصنيف بدقة
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
            'rawAiName': (item['productName'] ?? item['name'] ?? 'Unknown Item').toString(),
            'mappedId': null,
            'mappedName': (item['productName'] ?? item['name'] ?? 'Unknown Item').toString(),
            'isNewProduct': true,
            'mainCategory': aiMainCat,
            'subCategory': aiSubCat,
            'qty': _getSafeInt(item['quantity'] ?? item['qty']),
            'price': parsedCost,
            'sellingPrice': 0.0,
            'conversionFactor': 1,
            'imagePath': null,
          };
        }).toList();
      } catch (e) {
        _extractedItems = [_getDefaultItem()];
      }
    } else {
      _extractedItems = [_getDefaultItem()];
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
          if (data['subCategories'] != null) {
            subCats = List<String>.from(data['subCategories']);
          }
          if (subCats.isEmpty) subCats = ['General'];

          // دمج الأقسام الإضافية القادمة من فايربيز مع الثوابت
          if (_localTaxonomy.containsKey(mainCat)) {
            for (String sub in subCats) {
              if (!_localTaxonomy[mainCat]!.contains(sub)) {
                _localTaxonomy[mainCat]!.add(sub);
              }
            }
          } else {
            _localTaxonomy[mainCat] = subCats;
          }
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  Map<String, dynamic> _getDefaultItem() {
    return {
      'rawAiName': 'New Item',
      'mappedId': null,
      'mappedName': 'New Item',
      'isNewProduct': true,
      'mainCategory': _localTaxonomy.keys.isNotEmpty ? _localTaxonomy.keys.first : 'General',
      'subCategory': _localTaxonomy.values.isNotEmpty ? _localTaxonomy.values.first.first : 'General',
      'qty': 1,
      'price': 0.0,
      'sellingPrice': 0.0,
      'conversionFactor': 1,
      'imagePath': null,
    };
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceNoController.dispose();
    super.dispose();
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
    item['mappedName'] != null &&
        item['mappedName'].toString().isNotEmpty &&
        item['mainCategory'] != null &&
        item['subCategory'] != null
    );
  }

  void _showImagePickerOptions(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إضافة صورة للمنتج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: appPrimaryColor)),
            const Divider(thickness: 2),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.purple, size: 30),
              title: const Text('توليد بالذكاء الاصطناعي ✨', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _extractedItems[index]['imagePath'] = 'AI_GENERATED';
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم توليد صورة افتراضية بنجاح!'), backgroundColor: Colors.purple));
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: appSecondaryColor, size: 30),
              title: const Text('التقاط بالكاميرا 📸', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('سيتم تفعيل الكاميرا لاحقاً'), backgroundColor: appSecondaryColor));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue, size: 30),
              title: const Text('اختيار من المعرض 🖼️', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم تفعيل المعرض لاحقاً'), backgroundColor: Colors.blue));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addNewMainCategory() {
    TextEditingController catController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text('إضافة تصنيف أساسي', style: TextStyle(fontFamily: 'Cairo', color: appSecondaryColor, fontWeight: FontWeight.bold))),
        content: TextField(
          controller: catController,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(hintText: 'اسم التصنيف بالإنجليزية', border: OutlineInputBorder()),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appSecondaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              String newCat = catController.text.trim();
              if (newCat.isNotEmpty) {
                Navigator.pop(ctx);

                setState(() {
                  _localTaxonomy[newCat] = ['General'];
                });

                try {
                  await FirebaseFirestore.instance.collection('categories').doc(newCat).set({
                    'name': newCat,
                    'subCategories': ['General'],
                  }, SetOptions(merge: true));
                } catch (e) {
                  debugPrint("خطأ: $e");
                }
              }
            },
            child: const Text('إضافة', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          )
        ],
      ),
    );
  }

  void _addNewSubCategory(String mainCategory) {
    TextEditingController catController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text('إضافة فرعي لـ $mainCategory', style: TextStyle(fontFamily: 'Cairo', color: appSecondaryColor, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        content: TextField(
          controller: catController,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(hintText: 'اسم التصنيف بالإنجليزية', border: OutlineInputBorder()),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appSecondaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              String newSubCat = catController.text.trim();
              if (newSubCat.isNotEmpty) {
                Navigator.pop(ctx);

                setState(() {
                  if (_localTaxonomy[mainCategory] != null) {
                    _localTaxonomy[mainCategory]!.add(newSubCat);
                  } else {
                    _localTaxonomy[mainCategory] = [newSubCat];
                  }
                });

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
            child: const Text('إضافة', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          )
        ],
      ),
    );
  }

  void _showProductSearchModal(int index) {
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
                    decoration: InputDecoration(
                      labelText: 'ابحث عن المنتج...',
                      prefixIcon: Icon(Icons.search, color: appSecondaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        currentQuery = val.toLowerCase();
                      });
                    },
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

                        if (docs.isEmpty) {
                          return const Center(child: Text('هذا الصنف غير مسجل.', style: TextStyle(fontFamily: 'Cairo')));
                        }

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            var data = docs[i].data() as Map<String, dynamic>;
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: Icon(Icons.inventory_2, color: appSecondaryColor),
                                title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${data['category']} - ${data['subCategory']} | رصيد: ${data['stockQuantity'] ?? 0}'),
                                onTap: () {
                                  setState(() {
                                    _extractedItems[index]['isNewProduct'] = false;
                                    _extractedItems[index]['mappedId'] = docs[i].id;
                                    _extractedItems[index]['mappedName'] = data['name'];

                                    String dbMain = data['category'] ?? _localTaxonomy.keys.first;
                                    String dbSub = data['subCategory'] ?? 'General';

                                    if (!_localTaxonomy.containsKey(dbMain)) {
                                      _localTaxonomy[dbMain] = [dbSub];
                                    } else if (!_localTaxonomy[dbMain]!.contains(dbSub)) {
                                      _localTaxonomy[dbMain]!.add(dbSub);
                                    }

                                    _extractedItems[index]['mainCategory'] = dbMain;
                                    _extractedItems[index]['subCategory'] = dbSub;

                                    if (data['price'] != null) {
                                      _extractedItems[index]['sellingPrice'] = _getSafeDouble(data['price']);
                                    }
                                  });
                                  Navigator.pop(ctx);
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
    if (_extractedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('الفاتورة فارغة!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: alertRed),
      );
      return;
    }

    if (!_isAllItemsReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('تأكد من إكمال بيانات التصنيف لجميع الأصناف!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: alertRed),
      );
      return;
    }

    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: CircularProgressIndicator(color: appSecondaryColor),
      ),
    );

    try {
      await PurchaseService().processApprovedInvoice(
        supplierName: _supplierController.text.trim(),
        invoiceNumber: _invoiceNoController.text.trim(),
        items: _extractedItems,
      );

      if (mounted) Navigator.pop(context);

      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('تم ترحيل الفاتورة بنجاح! 🎉', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: appSecondaryColor), textAlign: TextAlign.center),
            content: const Text(
              'تم تحديث المخزون، إنشاء القيد المحاسبي، وأرشفة الفاتورة كمسودة.',
              style: TextStyle(fontFamily: 'Cairo'),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: appSecondaryColor, padding: const EdgeInsets.symmetric(horizontal: 30)),
                onPressed: () {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الترحيل: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: alertRed),
        );
      }
    }
  }

  void _addNewItemManually() {
    setState(() {
      _extractedItems.add(_getDefaultItem());
    });
    HapticFeedback.lightImpact();
  }

  void _removeItem(int index) {
    setState(() {
      _extractedItems.removeAt(index);
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCategories) {
      return Scaffold(
        backgroundColor: appBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: appSecondaryColor)),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: appBackgroundColor,
        appBar: AppBar(
          title: const Text('مراجعة وتسكين الفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          centerTitle: true,
          backgroundColor: appPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shadowColor: appPrimaryColor.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('بيانات المورد الأساسية', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: appSecondaryColor)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _supplierController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                            labelText: 'اسم المورد',
                            labelStyle: TextStyle(color: appSecondaryColor),
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                            isDense: true
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _invoiceNoController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                            labelText: 'رقم الفاتورة',
                            labelStyle: TextStyle(color: appSecondaryColor),
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                            isDense: true
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

                  bool isItemComplete = item['mappedName'] != null &&
                      item['mappedName'].toString().isNotEmpty &&
                      item['mainCategory'] != null &&
                      item['subCategory'] != null;

                  Color cardBorderColor = isItemComplete ? successGreen : alertRed;

                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cardBorderColor, width: 2)
                    ),
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
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(color: appPrimaryColor, shape: BoxShape.circle),
                                    child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _removeItem(index),
                                    tooltip: 'حذف الصنف من الفاتورة',
                                  ),
                                ],
                              ),
                              if (isNew)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: appSecondaryColor,
                                      side: BorderSide(color: appSecondaryColor, width: 1.5),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      minimumSize: const Size(0, 32),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                  ),
                                  icon: const Icon(Icons.link, size: 16),
                                  label: const Text('دفعة لصنف مسجل', style: TextStyle(fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                  onPressed: () => _showProductSearchModal(index),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: successGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 16, color: successGreen),
                                      const SizedBox(width: 6),
                                      Text('مربوط بصنف مسجل', style: TextStyle(fontSize: 12, color: successGreen, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            item['isNewProduct'] = true;
                                            item['mappedId'] = null;
                                            item['mappedName'] = item['rawAiName'];
                                          });
                                        },
                                        child: const Icon(Icons.close, size: 18, color: Colors.red),
                                      )
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
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isNew ? appSecondaryColor : Colors.grey.shade300, width: 1.5),
                                  ),
                                  child: item['imagePath'] == 'AI_GENERATED'
                                      ? const Center(child: Icon(Icons.auto_awesome, color: Colors.purple, size: 35))
                                      : item['imagePath'] != null
                                      ? const Center(child: Icon(Icons.check_circle, color: Colors.green))
                                      : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, color: isNew ? appSecondaryColor : Colors.grey, size: 24),
                                      const SizedBox(height: 4),
                                      Text('صورة', style: TextStyle(fontSize: 10, color: isNew ? appSecondaryColor : Colors.grey, fontFamily: 'Cairo')),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: item['mappedName'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  decoration: InputDecoration(
                                    labelText: isNew ? 'الاسم الذي سيُسجل به' : 'اسم الصنف المسجل (مقفل)',
                                    labelStyle: TextStyle(color: appSecondaryColor),
                                    alignLabelWithHint: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                    fillColor: isNew ? Colors.white : Colors.grey.shade100,
                                    filled: true,
                                    isDense: true,
                                  ),
                                  readOnly: !isNew,
                                  onChanged: (val) => setState(() => item['mappedName'] = val),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: item['price'].toString(),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'سعر الشراء (التكلفة)',
                                    prefixText: 'EGP ',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                  ),
                                  onChanged: (val) => setState(() => item['price'] = double.tryParse(val) ?? 0.0),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: item['sellingPrice'].toString(),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: appSecondaryColor),
                                  decoration: InputDecoration(
                                    labelText: 'سعر البيع للجمهور',
                                    prefixText: 'EGP ',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                  ),
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
                                  initialValue: item['qty'].toString(),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
                                  decoration: InputDecoration(
                                    labelText: 'الكمية',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                  ),
                                  onChanged: (val) => setState(() => item['qty'] = int.tryParse(val) ?? 1),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: item['conversionFactor'].toString(),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'الكرتونة (كم قطعة؟)',
                                    hintText: '1',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: appSecondaryColor, width: 2)),
                                  ),
                                  onChanged: (val) => item['conversionFactor'] = int.tryParse(val) ?? 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: appPrimaryColor.withOpacity(0.02),
                                border: Border.all(color: appSecondaryColor.withOpacity(0.4)),
                                borderRadius: BorderRadius.circular(10)
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('التصنيف المحاسبي والمخزني:', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: appSecondaryColor)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _localTaxonomy.containsKey(item['mainCategory']) ? item['mainCategory'] : (_localTaxonomy.keys.isNotEmpty ? _localTaxonomy.keys.first : null),
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                            labelText: 'التصنيف الأساسي',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            isDense: true
                                        ),
                                        items: _localTaxonomy.keys.map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 14)))).toList(),
                                        onChanged: !isNew ? null : (val) {
                                          setState(() {
                                            item['mainCategory'] = val!;
                                            item['subCategory'] = _localTaxonomy[val]!.isNotEmpty ? _localTaxonomy[val]!.first : 'General';
                                          });
                                        },
                                      ),
                                    ),
                                    if (isNew) ...[
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 40,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(Icons.add_circle, color: appSecondaryColor, size: 28),
                                          onPressed: _addNewMainCategory,
                                          tooltip: 'إضافة تصنيف أساسي جديد',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _localTaxonomy[item['mainCategory']]?.contains(item['subCategory']) == true
                                            ? item['subCategory']
                                            : (_localTaxonomy[item['mainCategory']]?.isNotEmpty == true ? _localTaxonomy[item['mainCategory']]!.first : null),
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                            labelText: 'التصنيف الفرعي',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            isDense: true
                                        ),
                                        items: (_localTaxonomy[item['mainCategory']] ?? []).map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 14)))).toList(),
                                        onChanged: !isNew ? null : (val) {
                                          setState(() {
                                            item['subCategory'] = val!;
                                          });
                                        },
                                      ),
                                    ),
                                    if (isNew) ...[
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 40,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(Icons.add_circle, color: appSecondaryColor, size: 28),
                                          onPressed: () => _addNewSubCategory(item['mainCategory']),
                                          tooltip: 'إضافة تصنيف فرعي جديد',
                                        ),
                                      ),
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
                  onPressed: _addNewItemManually,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: appPrimaryColor,
                    side: BorderSide(color: appPrimaryColor, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة صنف جديد للفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),

              Container(
                margin: const EdgeInsets.only(bottom: 40),
                child: ElevatedButton.icon(
                  onPressed: _approveAndSaveInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appSecondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.save_alt, color: Colors.white),
                  label: Text(
                    'تأكيد وحفظ الفاتورة (${_calculateGrandTotal.toStringAsFixed(2)} EGP)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}