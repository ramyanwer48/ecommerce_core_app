import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'supplier_ledger_screen.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _suppliersCollection = 'suppliers';

  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  String _searchQuery = '';
  List<String> _selectedSupplierIds = [];

  @override
  void initState() {
    super.initState();
    _migrateRemainingSuppliersIfNeeded();
  }

  Future<void> _migrateRemainingSuppliersIfNeeded() async {
    try {
      final oldSuppliersSnap = await _firestore
          .collection('partners')
          .where('type', isEqualTo: 'supplier')
          .get();

      if (oldSuppliersSnap.docs.isNotEmpty) {
        WriteBatch batch = _firestore.batch();
        for (var doc in oldSuppliersSnap.docs) {
          DocumentReference newRef = _firestore.collection(_suppliersCollection).doc(doc.id);
          batch.set(newRef, doc.data(), SetOptions(merge: true));
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Auto supplier migration check: $e');
    }
  }

  double _parseSafeBalance(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  void _showAddSupplierModal(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 20,
                  right: 20,
                  top: 20,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Text(
                        'إضافة مورد جديد',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                          color: primaryNavy,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: nameController,
                        style: const TextStyle(fontFamily: 'Cairo'),
                        decoration: InputDecoration(
                          labelText: 'اسم المورد',
                          labelStyle: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: brandOrange, width: 2),
                          ),
                          prefixIcon: Icon(Icons.storefront, color: brandOrange),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontFamily: 'Cairo'),
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف (اختياري)',
                          labelStyle: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: brandOrange, width: 2),
                          ),
                          prefixIcon: Icon(Icons.phone_android, color: brandOrange),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: brandOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty) return;
                          DocumentReference docRef = _firestore.collection(_suppliersCollection).doc();
                          await docRef.set({
                            'id': docRef.id,
                            'name': nameController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'type': 'supplier',
                            'balance': 0.0,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم حفظ المورد بنجاح في جدول الموردين',
                                    style: TextStyle(fontFamily: 'Cairo')),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'حفظ البيانات',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🌟 شاشة الفلتر المتعدد المحدثة (مع زر X المربع الأنيق)
  void _showFilterModal(List<QueryDocumentSnapshot> allSuppliers) {
    List<String> tempSelected = List.from(_selectedSupplierIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // هيدر نافذة الفلتر مع زر الإغلاق المربع
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تصفية حسب المورد',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                            color: primaryNavy,
                          ),
                        ),
                        Row(
                          children: [
                            if (tempSelected.isNotEmpty)
                              TextButton(
                                onPressed: () => setModalState(() => tempSelected.clear()),
                                child: Text(
                                  'إلغاء التحديد',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.black, width: 1.5),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.black, size: 16),
                                onPressed: () => Navigator.pop(context),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: ListView.builder(
                        itemCount: allSuppliers.length,
                        itemBuilder: (context, index) {
                          final doc = allSuppliers[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String id = doc.id;
                          final String name = data['name'] ?? 'بدون اسم';

                          final bool isSelected = tempSelected.contains(id);

                          return CheckboxListTile(
                            title: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                            value: isSelected,
                            activeColor: brandOrange,
                            checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            onChanged: (bool? value) {
                              setModalState(() {
                                if (value == true) {
                                  tempSelected.add(id);
                                } else {
                                  tempSelected.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedSupplierIds = List.from(tempSelected);
                          });
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'تطبيق الفلتر',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
          ],
          title: const Text(
            'حسابات الموردين',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: primaryNavy,
          elevation: 0,
        ),
        body: Column(
          children: [
            // شريط البحث والفلتر
            Container(
              color: primaryNavy,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection(_suppliersCollection).snapshots(),
                builder: (context, snapshot) {
                  List<QueryDocumentSnapshot> allDocs = snapshot.hasData ? snapshot.data!.docs : [];
                  bool hasFilter = _selectedSupplierIds.isNotEmpty;

                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'ابحث عن مورد...',
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      if (hasFilter) ...[
                        InkWell(
                          onTap: () => setState(() => _selectedSupplierIds.clear()),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Icon(Icons.close_rounded, color: Colors.red.shade700),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // 🌟 زر الفلتر بإطار أبيض صريح حسب الطلب
                      InkWell(
                        onTap: () {
                          if (allDocs.isNotEmpty) {
                            _showFilterModal(allDocs);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: hasFilter ? brandOrange : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1.5), // إطار أبيض
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.filter_list_rounded, color: Colors.white),
                              if (hasFilter)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${_selectedSupplierIds.length}',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: brandOrange,
                                      ),
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection(_suppliersCollection).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: brandOrange));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'حدث خطأ: ${snapshot.error}',
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store_mall_directory_outlined,
                              size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد حسابات موردين مسجلة حتى الآن.',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  var suppliers = snapshot.data!.docs.toList();

                  if (_selectedSupplierIds.isNotEmpty) {
                    suppliers =
                        suppliers.where((doc) => _selectedSupplierIds.contains(doc.id)).toList();
                  }

                  if (_searchQuery.isNotEmpty) {
                    suppliers = suppliers.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery);
                    }).toList();
                  }

                  suppliers.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;
                    final timeA = dataA['createdAt'] as Timestamp?;
                    final timeB = dataB['createdAt'] as Timestamp?;
                    if (timeA == null || timeB == null) return 0;
                    return timeB.compareTo(timeA);
                  });

                  if (suppliers.isEmpty) {
                    return Center(
                      child: Text(
                        'لم يتم العثور على موردين يطابقون بحثك.',
                        style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: suppliers.length,
                    itemBuilder: (context, index) {
                      final doc = suppliers[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final supplierId = doc.id;
                      final supplierName = data['name'] ?? 'بدون اسم';
                      final supplierPhone = data['phone'] ?? '';
                      final double balance = _parseSafeBalance(data['balance']);

                      String balanceText = balance < 0
                          ? balance.abs().toStringAsFixed(2)
                          : (balance > 0 ? balance.toStringAsFixed(2) : '0.0');

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PartnerLedgerScreen(
                                  partnerId: supplierId,
                                  partnerName: supplierName,
                                  partnerType: 'supplier',
                                  currentBalance: balance,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: brandOrange.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.storefront_rounded,
                                      color: brandOrange, size: 20),
                                ),
                                const SizedBox(width: 12),

                                // 🌟 اسم المورد مرن ولا يقص أبداً
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        supplierName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Cairo',
                                          fontSize: 14,
                                          color: primaryNavy,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: brandOrange.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'مورد معتمد',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontFamily: 'Cairo',
                                                color: brandOrange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (supplierPhone.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 3,
                                              height: 3,
                                              decoration: const BoxDecoration(
                                                color: Colors.grey,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              supplierPhone,
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 🌟 كارت الرصيد (خلفية كحلي ورقم برتقالي)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: primaryNavy,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: brandOrange, width: 1.2),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'الرصيد',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 9,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            balanceText,
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              color: brandOrange,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          const Text(
                                            'ج',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              color: Colors.white70,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddSupplierModal(context),
          backgroundColor: brandOrange,
          elevation: 2,
          icon: const Icon(Icons.add, color: Colors.white, size: 20),
          label: const Text(
            'إضافة مورد',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}