import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  // نافذة تسجيل مصروف أو سحب نقدي
  void _showAddExpenseDialog() {
    TextEditingController amountCtrl = TextEditingController();
    TextEditingController noteCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.money_off_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Text('تسجيل مصروف أو سحب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                decoration: InputDecoration(
                  labelText: 'المبلغ (ج.م)',
                  labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'البيان (السبب)',
                  hintText: 'مثال: فاتورة كهرباء، سحب شخصي، بوفيه...',
                  labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.notes),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                double amount = double.tryParse(amountCtrl.text) ?? 0.0;
                String note = noteCtrl.text.trim();

                if (amount > 0 && note.isNotEmpty) {
                  // تسجيل المصروف في دفتر الأستاذ (الخزينة)
                  await _firestore.collection('ledger_entries').add({
                    'type': 'expense', // نوع الحركة: مصروف
                    'amount': amount,
                    'date': FieldValue.serverTimestamp(),
                    'note': note,
                    'partnerName': 'إدارة الشركة',
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم خصم المبلغ من الخزينة بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                  }
                }
              },
              child: const Text('خصم وحفظ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('الخزينة والماليات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.red.shade600,
          onPressed: _showAddExpenseDialog,
          icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
          label: const Text('تسجيل مصروف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        body: StreamBuilder<QuerySnapshot>(
          // بنجيب كل الحركات المالية من الأحدث للأقدم
          stream: _firestore.collection('ledger_entries').orderBy('date', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
            if (snapshot.hasError) return const Center(child: Text('حدث خطأ في تحميل البيانات', style: TextStyle(fontFamily: 'Cairo')));

            double totalIncome = 0.0;
            double totalExpense = 0.0;
            List<QueryDocumentSnapshot> entries = snapshot.data?.docs ?? [];

            // حساب الإيرادات والمصروفات
            for (var doc in entries) {
              final data = doc.data() as Map<String, dynamic>;
              String type = data['type'] ?? '';
              double amount = double.tryParse((data['amount'] ?? 0).toString()) ?? 0.0;

              // القبض (مبيعات POS، تحصيل أونلاين، إيرادات أخرى)
              if (type == 'receipt' || type == 'income') {
                totalIncome += amount;
              }
              // الدفع (مشتريات، مصروفات)
              else if (type == 'payment' || type == 'expense') {
                totalExpense += amount;
              }
            }

            double netBalance = totalIncome - totalExpense;

            return Column(
              children: [
                // ================= الداشبورد العلوي =================
                Container(
                  color: primaryNavy,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: [
                      // كارت الصافي (الرصيد الحالي)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF1B2A47), Color(0xFF23395B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            const Text('رصيد الخزينة الحالي (السيولة)', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 8),
                            Text('${netBalance.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // كروت الإيرادات والمصروفات
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
                              child: Column(
                                children: [
                                  const Icon(Icons.arrow_downward_rounded, color: Colors.green, size: 20),
                                  const SizedBox(height: 4),
                                  const Text('إجمالي المقبوضات', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 11)),
                                  Text('${totalIncome.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Cairo', color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.3))),
                              child: Column(
                                children: [
                                  const Icon(Icons.arrow_upward_rounded, color: Colors.red, size: 20),
                                  const SizedBox(height: 4),
                                  const Text('إجمالي المدفوعات', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 11)),
                                  Text('${totalExpense.toStringAsFixed(2)}', style: TextStyle(fontFamily: 'Cairo', color: Colors.red.shade300, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ================= سجل الحركات =================
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.history, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('سجل الحركات المالية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 16)),
                    ],
                  ),
                ),

                Expanded(
                  child: entries.isEmpty
                      ? const Center(child: Text('لا توجد حركات مالية مسجلة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final data = entries[index].data() as Map<String, dynamic>;
                      String type = data['type'] ?? '';
                      double amount = double.tryParse((data['amount'] ?? 0).toString()) ?? 0.0;
                      String note = data['note'] ?? 'بدون بيان';
                      String partner = data['partnerName'] ?? '';

                      // تحديد شكل الحركة (قبض ولا دفع)
                      bool isIncome = (type == 'receipt' || type == 'income');
                      // استثناء مبيعات الأجل (لأنها مش فلوس دخلت الدرج لسه)
                      if (type == 'sale' || type == 'purchase') return const SizedBox.shrink();

                      DateTime date = DateTime.now();
                      if (data['date'] != null) date = (data['date'] as Timestamp).toDate();
                      String timeStr = '${date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour)}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'م' : 'ص'}';
                      String dateStr = '${date.day}/${date.month}/${date.year}';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                            child: Icon(isIncome ? Icons.add_rounded : Icons.remove_rounded, color: isIncome ? Colors.green : Colors.red),
                          ),
                          title: Text(note, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('$partner • $dateStr $timeStr', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                          trailing: Text(
                              '${isIncome ? '+' : '-'}${amount.toStringAsFixed(2)} ج.م',
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red, fontSize: 14)
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}