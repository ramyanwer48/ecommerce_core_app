import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'partner_ledger_screen.dart';

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  String _searchQuery = '';
  List<String> _selectedSupplierIds = []; // لحفظ ID الموردين المختارين في الفلتر

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
                    top: 20),
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
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      Text('إضافة مورد جديد',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: primaryNavy),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      TextField(
                        controller: nameController,
                        style: const TextStyle(fontFamily: 'Cairo'),
                        decoration: InputDecoration(
                          labelText: 'اسم المورد',
                          labelStyle: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 2)),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 2)),
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
                          await _firestore.collection('partners').add({
                            'name': nameController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'type': 'supplier',
                            'balance': 0.0,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المورد بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                          }
                        },
                        child: const Text('حفظ البيانات', style: TextStyle(fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
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

  // شاشة الفلتر المتعدد (Multi-Select)
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
                height: MediaQuery.of(context).size.height * 0.7, // يأخذ 70% من الشاشة
                padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('تصفية حسب المورد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: primaryNavy)),
                        if (tempSelected.isNotEmpty)
                          TextButton(
                            onPressed: () => setModalState(() => tempSelected.clear()),
                            child: Text('إلغاء التحديد', style: TextStyle(fontFamily: 'Cairo', color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                    const Divider(),
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
                            title: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                            value: isSelected,
                            activeColor: brandOrange,
                            checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: brandOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedSupplierIds = List.from(tempSelected);
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('تطبيق الفلتر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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
          title: const Text('حسابات الموردين', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
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
                // نستدعي هنا كل الموردين مرة واحدة لنمررهم لشاشة الفلتر
                  stream: _firestore.collection('partners').where('type', isEqualTo: 'supplier').snapshots(),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // زر إلغاء الفلتر (يظهر إذا كان هناك موردين محددين)
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

                        // زر الفلتر
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
                              color: hasFilter ? brandOrange : primaryNavy.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: brandOrange),
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
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: Text('${_selectedSupplierIds.length}', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: brandOrange)),
                                    ),
                                  )
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('partners').where('type', isEqualTo: 'supplier').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
                  if (snapshot.hasError) return Center(child: Text('حدث خطأ: ${snapshot.error}', style: const TextStyle(fontFamily: 'Cairo')));

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store_mall_directory_outlined, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('لا توجد حسابات موردين مسجلة حتى الآن.', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }

                  // 1. استخراج كل البيانات
                  var partners = snapshot.data!.docs.toList();

                  // 2. تطبيق فلتر الاختيار (Multi-Select)
                  if (_selectedSupplierIds.isNotEmpty) {
                    partners = partners.where((doc) => _selectedSupplierIds.contains(doc.id)).toList();
                  }

                  // 3. تطبيق فلتر البحث النصي
                  if (_searchQuery.isNotEmpty) {
                    partners = partners.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery);
                    }).toList();
                  }

                  // ترتيب محلي
                  partners.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;
                    final timeA = dataA['createdAt'] as Timestamp?;
                    final timeB = dataB['createdAt'] as Timestamp?;
                    if (timeA == null || timeB == null) return 0;
                    return timeB.compareTo(timeA);
                  });

                  if (partners.isEmpty) {
                    return Center(
                      child: Text('لم يتم العثور على موردين يطابقون بحثك.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: partners.length,
                    itemBuilder: (context, index) {
                      final doc = partners[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final partnerId = doc.id;
                      final partnerName = data['name'] ?? 'بدون اسم';
                      final partnerPhone = data['phone'] ?? '';
                      final double balance = (data['balance'] ?? 0).toDouble();

                      String balanceText = balance < 0 ? '${balance.abs().toStringAsFixed(2)}' : (balance > 0 ? '${balance.toStringAsFixed(2)}' : '0.0');

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
                                  partnerId: partnerId,
                                  partnerName: partnerName,
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
                                    color: brandOrange.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.storefront_rounded, color: brandOrange, size: 20),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        partnerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14, color: primaryNavy),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text('مورد', style: TextStyle(fontSize: 10, fontFamily: 'Cairo', color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                                          if (partnerPhone.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                                            const SizedBox(width: 8),
                                            Text(partnerPhone, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade600)),
                                          ]
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 👈 الرصيد داخل خلفية كحلي فاتح مميزة
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: primaryNavy.withOpacity(0.05), // خلفية كحلي خفيفة جداً
                                    borderRadius: BorderRadius.circular(8), // حواف دائرية ناعمة
                                    border: Border.all(color: primaryNavy.withOpacity(0.1)), // إطار خفيف
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text('الرصيد', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            balanceText,
                                            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 13),
                                          ),
                                          const SizedBox(width: 2),
                                          Text('ج', style: TextStyle(fontFamily: 'Cairo', color: brandOrange, fontSize: 10, fontWeight: FontWeight.bold)),
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
          label: const Text('إضافة مورد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
        ),
      ),
    );
  }
}