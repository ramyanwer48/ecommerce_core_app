import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

class PartnerLedgerScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String partnerType;
  final double currentBalance;

  const PartnerLedgerScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    required this.partnerType,
    required this.currentBalance,
  });

  @override
  State<PartnerLedgerScreen> createState() => _PartnerLedgerScreenState();
}

class _PartnerLedgerScreenState extends State<PartnerLedgerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  void _showPaymentSheet(BuildContext context, {DocumentSnapshot? existingDoc}) {
    final bool isEditing = existingDoc != null;
    final Map<String, dynamic>? data = isEditing ? existingDoc.data() as Map<String, dynamic>? : null;

    final TextEditingController amountController = TextEditingController(
      text: isEditing ? (data?['amount'] ?? '').toString() : '',
    );
    final TextEditingController noteController = TextEditingController(
      text: isEditing ? (data?['note'] ?? '') : '',
    );

    bool isSupplier = widget.partnerType == 'supplier';
    String paymentTitle = isEditing
        ? 'تعديل سند الصرف'
        : (isSupplier ? 'تسجيل سند صرف (دفع للمورد)' : 'تسجيل سند قبض (تحصيل من عميل)');
    String actionWord = isSupplier ? 'دفعت' : 'حصلت';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          // 👈 حل مشكلة الكيبورد بحيث ترتفع النافذة معها أوتوماتيكياً
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
                Text(paymentTitle, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy), textAlign: TextAlign.center),
                const SizedBox(height: 20),

                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: primaryNavy),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(labelText: 'المبلغ ($actionWord كام؟)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixText: 'ج.م'),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: noteController,
                  decoration: InputDecoration(labelText: 'البيان (مثال: دفعة نقدية تحت الحساب)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    String amountText = amountController.text.trim();
                    if (amountText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال المبلغ', style: TextStyle(fontFamily: 'Cairo'))));
                      return;
                    }

                    double newAmount = double.tryParse(amountText) ?? 0;
                    if (newAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المبلغ يجب أن يكون أكبر من صفر', style: TextStyle(fontFamily: 'Cairo'))));
                      return;
                    }

                    try {
                      WriteBatch batch = _firestore.batch();
                      DocumentReference partnerRef = _firestore.collection('partners').doc(widget.partnerId);

                      if (isEditing) {
                        // 🛡️ تأمين قراءة المبلغ القديم لمنع إيرور الـ Null Check
                        double oldAmount = 0.0;
                        if (data != null && data.containsKey('amount')) {
                          oldAmount = (data['amount'] ?? 0.0).toDouble();
                        }

                        double difference = newAmount - oldAmount; // الفارق الحسابي

                        DocumentReference ledgerRef = existingDoc.reference;
                        batch.update(ledgerRef, {
                          'amount': newAmount,
                          'note': noteController.text.isEmpty ? 'سند صرف معدل' : noteController.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        if (difference != 0) {
                          batch.update(partnerRef, {
                            'balance': FieldValue.increment(difference),
                          });
                        }
                      } else {
                        DocumentReference ledgerRef = _firestore.collection('ledger_entries').doc();
                        batch.set(ledgerRef, {
                          'partnerId': widget.partnerId,
                          'partnerName': widget.partnerName,
                          'type': 'payment',
                          'amount': newAmount,
                          'date': FieldValue.serverTimestamp(),
                          'note': noteController.text.isEmpty ? 'سند صرف نقدي' : noteController.text.trim(),
                        });

                        batch.update(partnerRef, {
                          'balance': FieldValue.increment(newAmount),
                        });
                      }

                      await batch.commit();

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEditing ? 'تم تعديل السند وتحديث الرصيد بنجاح' : 'تم تسجيل سند الصرف بنجاح وتحديث الرصيد', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ أثناء الحفظ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: Text(isEditing ? 'تعديل وحفظ التغيير' : 'حفظ وتسجيل سند الصرف', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteLedgerEntry(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    double amount = (data['amount'] ?? 0.0).toDouble();

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الحركة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذا السند؟ سيتم عكس أثره من رصيد المورد تلقائياً.', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
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

        DocumentReference partnerRef = _firestore.collection('partners').doc(widget.partnerId);
        batch.update(partnerRef, {
          'balance': FieldValue.increment(-amount),
        });

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف السند وعكس الرصيد بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ أثناء الحذف: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
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
          title: Text('كشف حساب: ${widget.partnerName}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('partners').doc(widget.partnerId).snapshots(),
              builder: (context, snapshot) {
                double liveBalance = widget.currentBalance;
                String phone = '';

                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  liveBalance = (data['balance'] ?? 0).toDouble();
                  phone = data['phone'] ?? '';
                }

                bool isCreditor = liveBalance < 0;

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                      color: primaryNavy,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: brandOrange.withOpacity(0.5), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 3))]
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: brandOrange.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                            child: const Text('مورد', style: TextStyle(fontFamily: 'Cairo', color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          const SizedBox(height: 6),
                          Text(phone.isEmpty ? 'بدون رقم هاتف' : phone, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('الرصيد الحالي', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text('${liveBalance.abs().toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', color: brandOrange, fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(isCreditor ? 'دائن (له أموال)' : 'مدين (عليه أموال)', style: TextStyle(fontFamily: 'Cairo', color: brandOrange.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(alignment: Alignment.centerRight, child: Text('حركة الحساب (Ledger) - (اضغط للتعديل أو اسحب للحذف)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey))),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('ledger_entries')
                    .where('partnerId', isEqualTo: widget.partnerId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: brandOrange));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('لا توجد حركات مالية مسجلة لهذا الحساب.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                    );
                  }

                  var docs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: docs.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      var doc = docs[index];
                      var data = doc.data() as Map<String, dynamic>;

                      String type = data['type'] ?? 'unknown';
                      double amount = (data['amount'] ?? 0).toDouble();
                      String note = data['note'] ?? '';
                      Timestamp? date = data['date'] as Timestamp?;

                      bool isPayment = type == 'payment';
                      IconData actionIcon = isPayment ? Icons.payments : Icons.receipt_long;
                      Color actionColor = brandOrange;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () {
                            if (isPayment) {
                              _showPaymentSheet(context, existingDoc: doc);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('فواتير المشتريات تُعدل من قسم الفواتير الأساسي', style: TextStyle(fontFamily: 'Cairo'))),
                              );
                            }
                          },
                          leading: CircleAvatar(backgroundColor: actionColor.withOpacity(0.1), child: Icon(actionIcon, color: actionColor)),
                          title: Text(isPayment ? 'سند صرف (دفعة نقدية)' : 'فاتورة مشتريات', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(note, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700)),
                              Text(_formatDate(date), style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${amount.toStringAsFixed(2)} ج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: actionColor)),
                              const SizedBox(width: 8),
                              if (isPayment)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => _deleteLedgerEntry(doc),
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
          onPressed: () => _showPaymentSheet(context),
          backgroundColor: brandOrange,
          elevation: 2,
          icon: const Icon(Icons.add_card, color: Colors.white),
          label: const Text('سند صرف (دفعة)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }
}