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

  // متغيرات الفلتر
  DateTime? _startDate;
  DateTime? _endDate;
  String _filterType = 'all'; // all, purchase, payment

  // دالة لتنسيق المبالغ وإزالة الأصفار العشرية لو كان الرقم صحيحاً
  String _formatMoney(double amount) {
    return amount.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
  }

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
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Text(paymentTitle, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy), textAlign: TextAlign.center),
                const SizedBox(height: 24),

                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: primaryNavy),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                      labelText: 'المبلغ ($actionWord كام؟)',
                      labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey.shade600),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 2)),
                      suffixText: 'ج.م',
                      suffixStyle: TextStyle(fontFamily: 'Cairo', color: brandOrange, fontWeight: FontWeight.bold)
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: noteController,
                  style: const TextStyle(fontFamily: 'Cairo'),
                  decoration: InputDecoration(
                    labelText: 'البيان (اختياري)',
                    labelStyle: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 2)),
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                        double oldAmount = 0.0;
                        if (data != null && data.containsKey('amount')) {
                          oldAmount = (data['amount'] ?? 0.0).toDouble();
                        }

                        double difference = newAmount - oldAmount;

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

  void _showFilterBottomSheet(BuildContext context) {
    String tempFilterType = _filterType;
    DateTime? tempStart = _startDate;
    DateTime? tempEnd = _endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Text('تصفية الحركات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy), textAlign: TextAlign.center),
                    const SizedBox(height: 24),

                    Text('نوع الحركة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildModalFilterChip('الكل', 'all', tempFilterType, (val) => setModalState(() => tempFilterType = val)),
                        _buildModalFilterChip('فواتير مشتريات', 'purchase', tempFilterType, (val) => setModalState(() => tempFilterType = val)),
                        _buildModalFilterChip('سندات صرف', 'payment', tempFilterType, (val) => setModalState(() => tempFilterType = val)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text('الفترة الزمنية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: tempStart != null && tempEnd != null
                              ? DateTimeRange(start: tempStart!, end: tempEnd!)
                              : null,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          helpText: 'اختر الفترة (من - إلى)',
                          cancelText: 'إلغاء',
                          confirmText: 'تأكيد',
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                scaffoldBackgroundColor: Colors.white,
                                dialogBackgroundColor: Colors.white,
                                colorScheme: ColorScheme.light(
                                  primary: brandOrange,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: primaryNavy,
                                ),
                              ),
                              child: Directionality(textDirection: TextDirection.rtl, child: child!),
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() {
                            tempStart = picked.start;
                            tempEnd = picked.end;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tempStart != null && tempEnd != null
                                  ? '${DateFormat('yyyy-MM-dd').format(tempStart!)}  إلى  ${DateFormat('yyyy-MM-dd').format(tempEnd!)}'
                                  : 'اختر من الكالندر (من - إلى)',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: tempStart != null ? primaryNavy : Colors.grey.shade600, fontWeight: tempStart != null ? FontWeight.bold : FontWeight.normal),
                            ),
                            Icon(Icons.calendar_month_rounded, color: brandOrange),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: brandOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                            onPressed: () {
                              setState(() {
                                _filterType = tempFilterType;
                                _startDate = tempStart;
                                _endDate = tempEnd;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('تطبيق الفلتر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: primaryNavy.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () {
                              setState(() {
                                _filterType = 'all';
                                _startDate = null;
                                _endDate = null;
                              });
                              Navigator.pop(context);
                            },
                            child: Text('مسح الفلتر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: primaryNavy)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalFilterChip(String label, String value, String currentValue, Function(String) onSelected) {
    bool isSelected = currentValue == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: brandOrange,
      labelStyle: TextStyle(color: isSelected ? Colors.white : primaryNavy),
      backgroundColor: Colors.white,
      showCheckmark: false,
      side: BorderSide(color: isSelected ? brandOrange : Colors.grey.shade300),
      onSelected: (bool selected) {
        if (selected) onSelected(value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasFilter = _filterType != 'all' || _startDate != null;

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
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('كشف حساب', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(widget.partnerName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white70)),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: primaryNavy,
          elevation: 0,
        ),
        body: Column(
          children: [
            // شريط الفلتر
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('تصفية الحركات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                  Row(
                    children: [
                      if (hasFilter) ...[
                        InkWell(
                          onTap: () => setState(() {
                            _filterType = 'all';
                            _startDate = null;
                            _endDate = null;
                          }),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 38,
                            width: 38,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Icon(Icons.close_rounded, color: Colors.red.shade700, size: 20),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      InkWell(
                        onTap: () => _showFilterBottomSheet(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            color: hasFilter ? brandOrange : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: brandOrange),
                          ),
                          child: Icon(Icons.tune_rounded, color: hasFilter ? Colors.white : brandOrange, size: 20),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            // بطاقة الرصيد الإجمالي
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
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: brandOrange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: brandOrange.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // بيانات المورد
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.store, size: 14, color: brandOrange),
                                  const SizedBox(width: 4),
                                  const Text('مورد', style: TextStyle(fontFamily: 'Cairo', color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.phone, size: 14, color: primaryNavy),
                                const SizedBox(width: 6),
                                Expanded(child: Text(phone.isEmpty ? 'بدون هاتف' : phone, style: TextStyle(fontFamily: 'Cairo', color: primaryNavy, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                              ],
                            )
                          ],
                        ),
                      ),

                      // 👈 الرصيد الإجمالي (معدل بالتوسيط والكبسولة الكحلي)
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('الرصيد الإجمالي', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            // كبسولة الرصيد
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryNavy, // 👈 خلفية كحلي
                                borderRadius: BorderRadius.circular(30), // حواف دائرية بالكامل
                              ),
                              child: Text(
                                  '${_formatMoney(liveBalance.abs())} ج.م',
                                  style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: isCreditor ? Colors.red.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4)
                              ),
                              child: Text(isCreditor ? 'دائن (له أموال)' : 'مدين (عليه أموال)', style: TextStyle(fontFamily: 'Cairo', color: isCreditor ? Colors.red : Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                  child: Text('كشف الحركات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy))
              ),
            ),

            // قائمة الحركات (فواتير + سندات)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('ledger_entries').where('partnerId', isEqualTo: widget.partnerId).snapshots(),
                builder: (context, ledgerSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('purchases').where('supplierName', isEqualTo: widget.partnerName).snapshots(),
                      builder: (context, purchasesSnapshot) {

                        if (ledgerSnapshot.connectionState == ConnectionState.waiting || purchasesSnapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: brandOrange));
                        }

                        List<Map<String, dynamic>> combinedEntries = [];

                        if (ledgerSnapshot.hasData) {
                          for (var doc in ledgerSnapshot.data!.docs) {
                            var data = doc.data() as Map<String, dynamic>;
                            data['docId'] = doc.id;
                            data['source'] = 'payment';
                            data['displayDate'] = data['date'];
                            combinedEntries.add(data);
                          }
                        }

                        if (purchasesSnapshot.hasData) {
                          for (var doc in purchasesSnapshot.data!.docs) {
                            var data = doc.data() as Map<String, dynamic>;
                            data['docId'] = doc.id;
                            data['source'] = 'purchase';
                            data['displayDate'] = data['date'];
                            combinedEntries.add(data);
                          }
                        }

                        if (_filterType != 'all') {
                          combinedEntries = combinedEntries.where((e) => e['source'] == _filterType).toList();
                        }

                        if (_startDate != null && _endDate != null) {
                          DateTime endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
                          combinedEntries = combinedEntries.where((e) {
                            Timestamp? t = e['displayDate'] as Timestamp?;
                            if (t == null) return false;
                            DateTime d = t.toDate();
                            return d.isAfter(_startDate!.subtract(const Duration(seconds: 1))) && d.isBefore(endOfDay.add(const Duration(seconds: 1)));
                          }).toList();
                        }

                        combinedEntries.sort((a, b) {
                          Timestamp? timeA = a['displayDate'] as Timestamp?;
                          Timestamp? timeB = b['displayDate'] as Timestamp?;
                          if (timeA == null || timeB == null) return 0;
                          return timeB.compareTo(timeA);
                        });

                        if (combinedEntries.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long, size: 50, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text('لا توجد حركات تطابق الفلتر.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: combinedEntries.length,
                          // 👈 تمت إضافة bottom: 90 لكي لا يُخفي الزر العائم الحركات الأخيرة
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
                          itemBuilder: (context, index) {
                            var entryData = combinedEntries[index];

                            bool isPurchase = entryData['source'] == 'purchase';
                            String title = isPurchase ? 'فاتورة مشتريات #${entryData['invoiceNumber'] ?? ''}' : 'سند صرف (دفعة نقدية)';
                            double amount = isPurchase ? (entryData['totalAmount'] ?? 0).toDouble() : (entryData['amount'] ?? 0).toDouble();
                            String note = isPurchase ? '${entryData['itemCount'] ?? 0} أصناف' : (entryData['note'] ?? '');
                            Timestamp? date = entryData['displayDate'] as Timestamp?;

                            IconData actionIcon = isPurchase ? Icons.shopping_cart_outlined : Icons.payments_outlined;
                            Color actionColor = isPurchase ? Colors.blue.shade700 : brandOrange;
                            Color bgColor = isPurchase ? Colors.blue.shade50 : brandOrange.withOpacity(0.1);

                            // 👈 تفريق لون كبسولة المبلغ بين الفاتورة (كحلي) والسند (برتقالي)
                            Color amountBgColor = isPurchase ? primaryNavy : brandOrange;

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                onTap: () {
                                  if (!isPurchase) {
                                    var docToEdit = ledgerSnapshot.data!.docs.firstWhere((doc) => doc.id == entryData['docId']);
                                    _showPaymentSheet(context, existingDoc: docToEdit);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('فواتير المشتريات تُعرض وتُعدل من قسم المشتريات', style: TextStyle(fontFamily: 'Cairo'))),
                                    );
                                  }
                                },
                                leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                                    child: Icon(actionIcon, color: actionColor, size: 22)
                                ),
                                title: Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(note, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600)),
                                    Text(_formatDate(date), style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: amountBgColor, // 👈 اللون الديناميكي للمبلغ
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                          '${_formatMoney(amount)} ج',
                                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)
                                      ),
                                    ),
                                    if (!isPurchase) ...[
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () {
                                          var docToDelete = ledgerSnapshot.data!.docs.firstWhere((doc) => doc.id == entryData['docId']);
                                          _deleteLedgerEntry(docToDelete);
                                        },
                                        child: const Text('حذف السند', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                      )
                                    ]
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
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
          icon: const Icon(Icons.add_card, color: Colors.white, size: 20),
          label: const Text('سند صرف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
        ),
      ),
    );
  }
}