import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_ledger_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;
  bool _isSyncing = false;

  Future<void> _syncCustomersFromOrders() async {
    setState(() => _isSyncing = true);
    try {
      QuerySnapshot ordersSnap = await _firestore.collection('orders').get();
      WriteBatch batch = _firestore.batch();
      Map<String, DocumentReference> newCustomersCache = {};
      int syncCount = 0;

      for (var doc in ordersSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;

        String name = '';
        if (data.containsKey('shippingAddress') && data['shippingAddress'] is Map) {
          var addr = data['shippingAddress'];
          name = '${addr['firstName'] ?? ''} ${addr['lastName'] ?? ''}'.trim();
          if (name.isEmpty) name = (addr['name'] ?? addr['fullName'] ?? '').toString().trim();
        }
        if (name.isEmpty) name = (data['userName'] ?? data['customerName'] ?? data['name'] ?? '').toString().trim();
        if (name.isEmpty) name = 'عميل أونلاين (${doc.id.substring(0, 4)})';

        String phone = '';
        if (data.containsKey('shippingAddress') && data['shippingAddress'] is Map) {
          phone = (data['shippingAddress']['phone'] ?? '').toString().trim();
        }
        if (phone.isEmpty) phone = (data['phone'] ?? data['customerPhone'] ?? '').toString().trim();

        double price = double.tryParse((data['totalPrice'] ?? data['totalAmount'] ?? data['grandTotal'] ?? data['amount'] ?? 0).toString()) ?? 0.0;
        if (price <= 0) continue;

        String status = data['status']?.toString().toLowerCase() ?? '';
        bool isPaid = data['isPaid'] == true || status == 'delivered' || status == 'تم التسليم';
        double netBalanceEffect = isPaid ? 0.0 : price;

        DocumentReference customerRef;
        String customerId;

        if (newCustomersCache.containsKey(name)) {
          customerRef = newCustomersCache[name]!;
          customerId = customerRef.id;
          if (netBalanceEffect > 0) batch.update(customerRef, {'balance': FieldValue.increment(netBalanceEffect)});
        } else {
          // 👈 التعديل هنا: بنقرأ ونكتب في كوليكشن customers المستقل
          QuerySnapshot customerSnap = await _firestore.collection('customers').where('name', isEqualTo: name).get();
          if (customerSnap.docs.isEmpty) {
            customerRef = _firestore.collection('customers').doc();
            customerId = customerRef.id;
            newCustomersCache[name] = customerRef;
            batch.set(customerRef, {
              'name': name,
              'phone': phone,
              'balance': netBalanceEffect,
              'createdAt': FieldValue.serverTimestamp(),
            });
          } else {
            customerRef = customerSnap.docs.first.reference;
            customerId = customerSnap.docs.first.id;
            if (netBalanceEffect > 0) batch.update(customerRef, {'balance': FieldValue.increment(netBalanceEffect)});
          }
        }

        DocumentReference saleRef = _firestore.collection('ledger_entries').doc('order_${doc.id}');
        batch.set(saleRef, {
          'partnerId': customerId,
          'partnerName': name,
          'type': 'sale',
          'amount': price,
          'date': data['createdAt'] ?? FieldValue.serverTimestamp(),
          'note': 'أوردر المتجر رقم: ${doc.id.substring(0, 5)}',
        }, SetOptions(merge: true));

        if (isPaid) {
          DocumentReference autoReceiptRef = _firestore.collection('ledger_entries').doc('auto_receipt_${doc.id}');
          batch.set(autoReceiptRef, {
            'partnerId': customerId,
            'partnerName': name,
            'type': 'receipt',
            'amount': price,
            'date': FieldValue.serverTimestamp(),
            'note': 'تحصيل أوتوماتيكي (تم التسليم/الدفع)',
          }, SetOptions(merge: true));
        }

        syncCount++;
      }

      if (syncCount > 0) await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم المزامنة بنجاح!', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showAddCustomerModal(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext modalContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('إضافة عميل جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: primaryNavy), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextField(controller: nameController, decoration: InputDecoration(labelText: 'اسم العميل', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.person))),
                  const SizedBox(height: 15),
                  TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.phone))),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: brandOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) return;
                      // 👈 التعديل هنا: الإضافة في كوليكشن customers
                      await _firestore.collection('customers').add({
                        'name': nameController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'balance': 0.0,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ العميل بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
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
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('حسابات العملاء (المدينون)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          actions: [
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.sync),
              tooltip: 'مزامنة أوردرات المتجر',
              onPressed: _isSyncing ? null : _syncCustomersFromOrders,
            ),
          ],
        ),
        // 👈 التعديل هنا: قراءة العملاء من كوليكشن customers فقط
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('customers').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
            if (snapshot.hasError) return Center(child: Text('حدث خطأ: ${snapshot.error}'));

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                      'لا توجد حسابات عملاء مسجلة حتى الآن.\nاضغط على أيقونة (🔄) بالأعلى لجلب الأوردرات أو أضف عميل يدوياً من الأسفل.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)
                  ),
                ),
              );
            }

            final customers = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final doc = customers[index];
                final data = doc.data() as Map<String, dynamic>;
                final customerId = doc.id;
                final customerName = data['name'] ?? 'بدون اسم';
                final customerPhone = data['phone'] ?? '';
                final double balance = (data['balance'] ?? 0).toDouble();

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: brandOrange.withOpacity(0.4), width: 1.5)),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerLedgerScreen(
                            customerId: customerId,
                            customerName: customerName,
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
                          CircleAvatar(radius: 22, backgroundColor: brandOrange.withOpacity(0.15), child: Icon(Icons.person, color: brandOrange, size: 22)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15, color: primaryNavy)),
                                const SizedBox(height: 4),
                                Text(customerPhone.isEmpty ? 'بدون هاتف' : customerPhone, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: const Color(0xFF1B2A4A), borderRadius: BorderRadius.circular(12), border: Border.all(color: brandOrange.withOpacity(0.6), width: 1.2)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('الرصيد', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                                Text('${balance.toStringAsFixed(2)} ج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: brandOrange, fontSize: 13)),
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
          onPressed: () => _showAddCustomerModal(context),
          backgroundColor: brandOrange,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('إضافة عميل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }
}