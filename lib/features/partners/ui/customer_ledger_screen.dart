import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

class CustomerLedgerScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final double currentBalance;

  const CustomerLedgerScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.currentBalance,
  });

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  void _showReceiptSheet(BuildContext context, {DocumentSnapshot? existingDoc}) {
    final bool isEditing = existingDoc != null;
    final Map<String, dynamic>? data = isEditing ? existingDoc.data() as Map<String, dynamic>? : null;

    final TextEditingController amountController = TextEditingController(
      text: isEditing ? (data?['amount'] ?? '').toString() : '',
    );
    final TextEditingController noteController = TextEditingController(
      text: isEditing ? (data?['note'] ?? '') : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditing ? 'تعديل سند القبض' : 'تسجيل سند قبض (تحصيل)',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: primaryNavy,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: primaryNavy,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'المبلغ المحصل (كام؟)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixText: 'ج.م',
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'البيان (مثال: دفعة نقدية تحت الحساب)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    String amountText = amountController.text.trim();
                    if (amountText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الرجاء إدخال المبلغ', style: TextStyle(fontFamily: 'Cairo'))),
                      );
                      return;
                    }

                    double newAmount = double.tryParse(amountText) ?? 0;
                    if (newAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('المبلغ يجب أن يكون أكبر من صفر', style: TextStyle(fontFamily: 'Cairo'))),
                      );
                      return;
                    }

                    try {
                      WriteBatch batch = _firestore.batch();
                      DocumentReference customerRef = _firestore.collection('customers').doc(widget.customerId);

                      if (isEditing) {
                        double oldAmount = 0.0;
                        if (data != null && data.containsKey('amount')) {
                          oldAmount = double.tryParse(data['amount'].toString()) ?? 0.0; // حماية
                        }

                        double difference = newAmount - oldAmount;

                        DocumentReference ledgerRef = existingDoc.reference;
                        batch.update(ledgerRef, {
                          'amount': newAmount,
                          'note': noteController.text.isEmpty ? 'سند قبض معدل' : noteController.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        if (difference != 0) {
                          batch.update(customerRef, {
                            'balance': FieldValue.increment(-difference),
                          });
                        }
                      } else {
                        DocumentReference ledgerRef = _firestore.collection('ledger_entries').doc();
                        batch.set(ledgerRef, {
                          'partnerId': widget.customerId,
                          'partnerName': widget.customerName,
                          'type': 'receipt',
                          'amount': newAmount,
                          'date': FieldValue.serverTimestamp(),
                          'note': noteController.text.isEmpty ? 'سند قبض نقدي' : noteController.text.trim(),
                        });

                        batch.update(customerRef, {
                          'balance': FieldValue.increment(-newAmount),
                        });
                      }

                      await batch.commit();

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEditing ? 'تم تعديل السند وتحديث الرصيد' : 'تم تسلم السند بنجاح',
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('خطأ أثناء الحفظ: $e', style: const TextStyle(fontFamily: 'Cairo')),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    isEditing ? 'تعديل وحفظ التغيير' : 'حفظ وتسجيل سند القبض',
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteReceiptEntry(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    double amount = double.tryParse((data['amount'] ?? 0).toString()) ?? 0.0; // حماية

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف سند القبض', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذا السند؟ سيتم عكس أثره وإعادة المبلغ لمديونية العميل.', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف وعكس الرصيد', style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        WriteBatch batch = _firestore.batch();
        batch.delete(doc.reference);

        DocumentReference customerRef = _firestore.collection('customers').doc(widget.customerId);
        batch.update(customerRef, {
          'balance': FieldValue.increment(amount),
        });

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف السند وعكس الرصيد بنجاح', style: TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ أثناء الحذف: $e', style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('yyyy-MM-dd | hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            'كشف حساب عميل: ${widget.customerName}',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('customers').doc(widget.customerId).snapshots(),
              builder: (context, snapshot) {
                double liveBalance = widget.currentBalance;
                String phone = '';

                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  liveBalance = double.tryParse((data['balance'] ?? 0).toString()) ?? 0.0;
                  phone = data['phone'] ?? '';
                }

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: primaryNavy,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: brandOrange.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: brandOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'عميل',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            phone.isEmpty ? 'بدون رقم هاتف' : phone,
                            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'إجمالي المديونية',
                            style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${liveBalance.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: brandOrange,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'حركة الحساب - (اضغط للتعديل أو الحذف)',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // 1. إزالة orderBy هنا
                stream: _firestore.collection('ledger_entries')
                    .where('partnerId', isEqualTo: widget.customerId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: brandOrange));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('خطأ في جلب السجل: ${snapshot.error}', style: const TextStyle(fontFamily: 'Cairo', color: Colors.red)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد تحصيلات أو فواتير مسجلة لهذا العميل.',
                        style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                      ),
                    );
                  }

                  // 2. الترتيب محلياً لتفادي خطأ الـ Index
                  var docs = snapshot.data!.docs.toList();
                  docs.sort((a, b) {
                    var dataA = a.data() as Map<String, dynamic>;
                    var dataB = b.data() as Map<String, dynamic>;
                    Timestamp? timeA = dataA['date'] as Timestamp? ?? dataA['createdAt'] as Timestamp? ?? dataA['updatedAt'] as Timestamp?;
                    Timestamp? timeB = dataB['date'] as Timestamp? ?? dataB['createdAt'] as Timestamp? ?? dataB['updatedAt'] as Timestamp?;
                    if (timeA == null && timeB == null) return 0;
                    if (timeA == null) return 1;
                    if (timeB == null) return -1;
                    return timeB.compareTo(timeA);
                  });

                  return ListView.builder(
                    itemCount: docs.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      var doc = docs[index];
                      var data = doc.data() as Map<String, dynamic>;

                      String type = data['type'] ?? 'unknown';
                      double amount = double.tryParse((data['amount'] ?? 0).toString()) ?? 0.0; // حماية
                      String note = data['note'] ?? '';
                      Timestamp? date = data['date'] as Timestamp? ?? data['createdAt'] as Timestamp? ?? data['updatedAt'] as Timestamp?;

                      bool isReceipt = type == 'receipt';
                      bool isSale = type == 'sale' || type == 'invoice';

                      if (!isReceipt && !isSale) return const SizedBox.shrink();

                      IconData actionIcon = isReceipt ? Icons.arrow_downward : Icons.receipt_long;
                      Color actionColor = isReceipt ? Colors.green.shade600 : brandOrange;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () {
                            if (isReceipt) {
                              _showReceiptSheet(context, existingDoc: doc);
                            }
                          },
                          leading: CircleAvatar(
                            backgroundColor: actionColor.withOpacity(0.1),
                            child: Icon(actionIcon, color: actionColor),
                          ),
                          title: Text(
                            isReceipt ? 'سند تحصيل نقدية' : 'فاتورة مبيعات',
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note,
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700),
                              ),
                              Text(
                                _formatDate(date),
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${amount.toStringAsFixed(2)} ج',
                                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: actionColor),
                              ),
                              const SizedBox(width: 8),
                              if (isReceipt)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => _deleteReceiptEntry(doc),
                                  tooltip: 'حذف السند',
                                ),
                            ],
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
          onPressed: () => _showReceiptSheet(context),
          backgroundColor: brandOrange,
          elevation: 2,
          icon: const Icon(Icons.add_card, color: Colors.white),
          label: const Text(
            'سند تحصيل',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}