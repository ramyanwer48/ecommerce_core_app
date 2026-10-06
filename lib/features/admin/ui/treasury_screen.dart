import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  late TabController _tabController;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14))),
            ],
          ),
          backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
          duration: const Duration(seconds: 3),
          elevation: 6,
        )
    );
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: brandOrange, onPrimary: Colors.white, onSurface: primaryNavy),
        ),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  bool _isWithinDateRange(Timestamp? timestamp) {
    if (_selectedDateRange == null || timestamp == null) return true;
    DateTime dt = timestamp.toDate();
    DateTime justDt = DateTime(dt.year, dt.month, dt.day);
    DateTime start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
    DateTime end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
    return !(justDt.isBefore(start) || justDt.isAfter(end));
  }

  void _showAddExpenseSheet() {
    TextEditingController amountCtrl = TextEditingController();
    TextEditingController noteCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: const Icon(Icons.money_off_rounded, color: Colors.red, size: 20)),
                              const SizedBox(width: 12),
                              Text('تسجيل مصروف جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 16)),
                            ],
                          ),
                          IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),

                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'المبلغ (ج.م)',
                          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: noteCtrl,
                        decoration: InputDecoration(
                          labelText: 'بند المصروف والبيان',
                          hintText: 'مثال: كهرباء، بوفيه، رواتب...',
                          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
                          prefixIcon: const Icon(Icons.notes),
                        ),
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isSaving ? null : () async {
                          double amount = double.tryParse(amountCtrl.text) ?? 0.0;
                          String note = noteCtrl.text.trim();

                          if (amount <= 0 || note.isEmpty) {
                            _showCustomSnackBar('يرجى إدخال المبلغ والبيان', isError: true);
                            return;
                          }

                          setSheetState(() => isSaving = true);
                          try {
                            await _firestore.collection('ledger_entries').add({
                              'type': 'expense',
                              'amount': amount,
                              'date': FieldValue.serverTimestamp(),
                              'note': note,
                              'partnerName': 'مصروفات تشغيلية',
                            });
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              _showCustomSnackBar('تم تسجيل المصروف وخصمه من الخزينة بنجاح');
                            }
                          } catch (e) {
                            setSheetState(() => isSaving = false);
                            _showCustomSnackBar('حدث خطأ أثناء الحفظ', isError: true);
                          }
                        },
                        child: isSaving
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('حفظ وخصم من الخزينة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          }
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
          title: const Text('المركز المالي والخزينة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.filter_list_rounded, color: _selectedDateRange != null ? brandOrange : Colors.white, size: 26),
                  onPressed: _pickDateRange,
                  tooltip: 'تصفية حسب الفترة',
                ),
                if (_selectedDateRange != null)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(width: 8, height: 8, decoration: BoxDecoration(color: brandOrange, shape: BoxShape.circle)),
                  )
              ],
            ),
            if (_selectedDateRange != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                onPressed: () => setState(() => _selectedDateRange = null),
                tooltip: 'إلغاء الفلتر',
              ),
            const SizedBox(width: 4),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.red.shade600,
          onPressed: _showAddExpenseSheet,
          icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
          label: const Text('تسجيل مصروف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('orders').where('status', isNotEqualTo: 'Cancelled').snapshots(),
          builder: (context, ordersSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('ledger_entries').orderBy('date', descending: true).snapshots(),
              builder: (context, ledgerSnap) {
                if (ordersSnap.connectionState == ConnectionState.waiting || ledgerSnap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: brandOrange));
                }

                double totalRevenues = 0;
                double totalCOGS = 0;
                for (var doc in ordersSnap.data?.docs ?? []) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (_isWithinDateRange(data['createdAt'] ?? data['orderDate'])) {
                    totalRevenues += double.tryParse((data['totalPrice'] ?? data['totalAmount'] ?? 0).toString()) ?? 0;
                    totalCOGS += double.tryParse((data['totalCostPrice'] ?? 0).toString()) ?? 0;
                  }
                }

                double totalCashIn = 0;
                double totalCashOut = 0;
                double totalExpenses = 0;
                List<QueryDocumentSnapshot> allMovements = [];
                List<QueryDocumentSnapshot> expenseMovements = [];

                for (var doc in ledgerSnap.data?.docs ?? []) {
                  var data = doc.data() as Map<String, dynamic>;
                  String type = data['type'] ?? '';
                  double amount = double.tryParse((data['amount'] ?? 0).toString()) ?? 0.0;

                  if (_isWithinDateRange(data['date'] ?? data['createdAt'])) {
                    if (type != 'sale' && type != 'purchase') {
                      allMovements.add(doc);
                    }
                    if (type == 'expense' || type == 'payment') {
                      expenseMovements.add(doc);
                      totalExpenses += amount;
                      totalCashOut += amount;
                    }
                    if (type == 'receipt' || type == 'income') {
                      totalCashIn += amount;
                    }
                  }
                }

                double grossProfit = totalRevenues - totalCOGS;
                double netProfit = grossProfit - totalExpenses;
                double currentLiquidity = totalCashIn - totalCashOut;

                return Column(
                  children: [
                    // شريط التبويبات فوق خالص
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: brandOrange,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorColor: brandOrange,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        tabs: const [
                          Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('الأرباح والخسائر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)))),
                          Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('السيولة النقدية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)))),
                          Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('سجل المصروفات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)))),
                        ],
                      ),
                    ),

                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildProfitAndLossTab(totalRevenues, totalCOGS, grossProfit, totalExpenses, netProfit),
                          _buildCashFlowTab(totalCashIn, totalCashOut, currentLiquidity, allMovements, totalExpenses),
                          _buildExpensesTab(expenseMovements, totalExpenses),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // 1. تبويب الأرباح والخسائر (البطل هنا: صافي الربح الفعلي)
  Widget _buildProfitAndLossTab(double rev, double cogs, double gross, double exp, double net) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: net >= 0 ? [Colors.green.shade700, Colors.green.shade500] : [Colors.red.shade800, Colors.red.shade600]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))]
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(net >= 0 ? Icons.emoji_events : Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(net >= 0 ? 'صافي الربح الفعلي' : 'صافي الخسارة', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${net.abs().toStringAsFixed(2)} ج.م',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 30),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          _buildFinancialCard('إجمالي إيرادات المبيعات', rev, Icons.trending_up, Colors.blue.shade700, 'قيمة البضاعة المباعة (كاش وآجل)'),
          const SizedBox(height: 12),
          _buildFinancialCard('تكلفة البضاعة المباعة', cogs, Icons.inventory_2_outlined, Colors.brown.shade600, 'سعر الشراء الأصلي للبضاعة المباعة', isMinus: true),
          const SizedBox(height: 12),
          _buildFinancialCard('مجمل الربح (التجاري)', gross, Icons.pie_chart_outline, Colors.purple.shade600, 'الربح قبل خصم المصروفات (المبيعات - التكلفة)'),
          const SizedBox(height: 12),
          _buildFinancialCard('المصروفات التشغيلية', exp, Icons.money_off, Colors.red.shade600, 'رواتب، كهرباء، إيجارات، إلخ', isMinus: true),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // 2. تبويب السيولة النقدية (البطل هنا: رصيد الخزينة الحالي بلون مميز كحلي/أزرق بترولي)
  Widget _buildCashFlowTab(double cashIn, double cashOut, double net, List<QueryDocumentSnapshot> movements, double totalExpenses) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              // 🚀 رصيد الخزينة الحالي في القمة وبلون مميز (Blue Grey / Slate)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1B3B4B), Color(0xFF1D3557)], begin: Alignment.topLeft, end: Alignment.bottomRight), // لون كحلي بترولي فخم // لون كحلي بترولي فخم
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))]
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.orangeAccent, size: 22),
                        SizedBox(width: 8),
                        Text('رصيد الخزينة الحالي (السيولة)', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${net.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(child: _buildMiniCard('النقدية الداخلة (+)', cashIn, Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMiniCard('المدفوعات (-)', cashOut, Colors.red)),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          width: double.infinity,
          color: const Color(0xFFF5F7FA),
          child: const Text('سجل حركات الخزينة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        Expanded(
          child: movements.isEmpty
              ? const Center(child: Text('لا توجد حركات نقدية', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
              : ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
            itemCount: movements.length,
            itemBuilder: (context, index) {
              final data = movements[index].data() as Map<String, dynamic>;
              String type = data['type'] ?? '';
              double amount = double.tryParse((data['amount'] ?? 0).toString()) ?? 0.0;
              String note = data['note'] ?? 'بدون بيان';
              String partner = data['partnerName'] ?? '';
              bool isIncome = (type == 'receipt' || type == 'income');

              DateTime date = DateTime.now();
              if (data['date'] != null) date = (data['date'] as Timestamp).toDate();
              String dateStr = DateFormat('yyyy/MM/dd | hh:mm a').format(date);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50, child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? Colors.green : Colors.red, size: 20)),
                  title: Text(note, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('$partner • $dateStr', style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
                  trailing: Text('${isIncome ? '+' : '-'}${amount.toStringAsFixed(2)}', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red, fontSize: 14)),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  // 3. تبويب سجل المصروفات (البطل هنا: إجمالي المصروفات في القمة بلون أحمر هادئ فخم)
  Widget _buildExpensesTab(List<QueryDocumentSnapshot> expenses, double totalExpenses) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))]
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.money_off, color: Colors.red.shade700, size: 22),
                  const SizedBox(width: 8),
                  Text('إجمالي المصروفات التشغيلية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red.shade900)),
                ],
              ),
              const SizedBox(height: 6),
              Text('${totalExpenses.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 28, color: Colors.red.shade700)),
            ],
          ),
        ),
        Expanded(
          child: expenses.isEmpty
              ? const Center(child: Text('لا توجد مصروفات في هذه الفترة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
              : ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              var doc = expenses[index];
              var data = doc.data() as Map<String, dynamic>;
              double amount = double.tryParse((data['amount'] ?? 0).toString()) ?? 0;
              String note = data['note'] ?? 'مصروف غير محدد';
              Timestamp? dateTs = data['date'];
              String dateStr = dateTs != null ? DateFormat('yyyy/MM/dd | hh:mm a').format(dateTs.toDate()) : '';

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade100)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.red.shade50, child: Icon(Icons.receipt_long, color: Colors.red.shade700)),
                  title: Text(note, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(dateStr, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${amount.toStringAsFixed(2)} ج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 15)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (ctx) => Directionality(
                                textDirection: TextDirection.rtl,
                                child: AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('إلغاء المصروف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                  content: const Text('هل أنت متأكد من حذف هذا المصروف؟\nسيتم إعادة المبلغ لعهدة الخزينة.', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع', style: TextStyle(fontFamily: 'Cairo'))),
                                    TextButton(
                                        onPressed: () {
                                          _firestore.collection('ledger_entries').doc(doc.id).delete();
                                          Navigator.pop(ctx);
                                          _showCustomSnackBar('تم حذف المصروف ورد المبلغ للخزينة بنجاح');
                                        },
                                        child: const Text('حذف واسترداد', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold))
                                    ),
                                  ],
                                ),
                              )
                          );
                        },
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialCard(String title, double amount, IconData icon, Color color, String subtitle, {bool isMinus = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 28)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Text('${isMinus && amount > 0 ? '-' : ''}${amount.toStringAsFixed(2)} ج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        ],
      ),
    );
  }

  Widget _buildMiniCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${amount.toStringAsFixed(2)}', style: TextStyle(fontFamily: 'Cairo', color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}