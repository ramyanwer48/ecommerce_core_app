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
  bool _isSyncing = false;

  Future<void> _syncSuppliersFromPurchases() async {
    setState(() => _isSyncing = true);
    try {
      QuerySnapshot purchasesSnap = await _firestore.collection('purchases').get();

      Map<String, double> supplierTotals = {};

      for (var doc in purchasesSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String supplierName = (data['supplierName'] ?? '').trim();
        double totalAmount = (data['totalAmount'] ?? 0).toDouble();

        if (supplierName.isNotEmpty) {
          supplierTotals[supplierName] = (supplierTotals[supplierName] ?? 0.0) + totalAmount;
        }
      }

      WriteBatch batch = _firestore.batch();

      for (var entry in supplierTotals.entries) {
        String name = entry.key;
        double totalDue = entry.value;

        QuerySnapshot existingPartner = await _firestore
            .collection('partners')
            .where('type', isEqualTo: 'supplier')
            .where('name', isEqualTo: name)
            .get();

        if (existingPartner.docs.isEmpty) {
          DocumentReference newDoc = _firestore.collection('partners').doc();
          batch.set(newDoc, {
            'name': name,
            'phone': '',
            'type': 'supplier',
            'balance': -totalDue,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          var docRef = existingPartner.docs.first.reference;
          var docData = existingPartner.docs.first.data() as Map<String, dynamic>;
          double currentBalance = (docData['balance'] ?? 0.0).toDouble();

          if (currentBalance == 0.0 && totalDue > 0) {
            batch.update(docRef, {'balance': -totalDue});
          }
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم مزامنة الموردين وأرصدتهم بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في المزامنة: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showAddSupplierModal(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('إضافة مورد جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: primaryNavy), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      TextField(controller: nameController, decoration: InputDecoration(labelText: 'اسم المورد', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.store))),
                      const SizedBox(height: 15),
                      TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.phone))),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: brandOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
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
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المورد بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
                          }
                        },
                        child: const Text('حفظ البيانات', style: TextStyle(fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 20),
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('حسابات الموردين', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          actions: [
            IconButton(
              icon: _isSyncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.sync),
              tooltip: 'مزامنة الموردين وأرصدتهم',
              onPressed: _isSyncing ? null : _syncSuppliersFromPurchases,
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('partners').where('type', isEqualTo: 'supplier').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
            if (snapshot.hasError) return Center(child: Text('حدث خطأ: ${snapshot.error}'));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('لا توجد حسابات مورّدين مسجلة حتى الآن.\nاضغط على زر المزامنة (🔄) فوق لجلب الموردين وأرصدتهم من الفواتير السابقة!', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
                        onPressed: _syncSuppliersFromPurchases,
                        icon: const Icon(Icons.sync),
                        label: const Text('مزامنة الفواتير القديمة', style: TextStyle(fontFamily: 'Cairo')),
                      )
                    ],
                  ),
                ),
              );
            }

            final partners = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: partners.length,
              itemBuilder: (context, index) {
                final doc = partners[index];
                final data = doc.data() as Map<String, dynamic>;
                final partnerId = doc.id;
                final partnerName = data['name'] ?? 'بدون اسم';
                final partnerPhone = data['phone'] ?? '';
                final double balance = (data['balance'] ?? 0).toDouble();

                String balanceText = balance < 0 ? '${balance.abs().toStringAsFixed(2)} ج' : (balance > 0 ? '${balance.toStringAsFixed(2)} ج' : '0.00 ج');

                return Card(
                  elevation: 2,
                  shadowColor: Colors.black12,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: brandOrange.withOpacity(0.4), width: 1.5),
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
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: brandOrange.withOpacity(0.15),
                            child: Icon(Icons.store, color: brandOrange, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    partnerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15, color: primaryNavy)
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: primaryNavy.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
                                      child: Text('مورد', style: TextStyle(fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(partnerPhone.isEmpty ? 'بدون هاتف' : partnerPhone, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B2A4A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: brandOrange.withOpacity(0.6), width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('الرصيد', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                    balanceText,
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        color: brandOrange,
                                        fontSize: 13
                                    )
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddSupplierModal(context),
          backgroundColor: brandOrange,
          elevation: 2,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('إضافة مورد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }
}