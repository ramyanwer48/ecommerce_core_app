import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryAuditScreen extends StatefulWidget {
  const InventoryAuditScreen({super.key});

  @override
  State<InventoryAuditScreen> createState() => _InventoryAuditScreenState();
}

class _InventoryAuditScreenState extends State<InventoryAuditScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // إعداد التابات الثلاثة
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('جرد المخزن وتقييم الأصول', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            labelColor: brandOrange,
            unselectedLabelColor: Colors.white70,
            indicatorColor: brandOrange,
            indicatorWeight: 4,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.fact_check_rounded), text: 'المطابقة (عجز/زيادة)'),
              Tab(icon: Icon(Icons.account_balance_wallet_rounded), text: 'تقييم رأس المال'),
              Tab(icon: Icon(Icons.delete_sweep_rounded), text: 'التوالف والهالك'),
            ],
          ),
        ),
        body: Column(
          children: [
            // شريط البحث الموحد
            Container(
              color: primaryNavy,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج للجرد...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),

            // محتوى التابات
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildReconciliationTab(), // 1. تاب المطابقة الفعلي مع الدفتري
                  _buildValuationTab(),      // 2. تاب تقييم رأس المال المتجمد
                  _buildSpoilageTab(),       // 3. تاب سجل التوالف
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // 1. التاب الأول: مطابقة الجرد (Reconciliation)
  // =====================================================================
  Widget _buildReconciliationTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('المخزن فارغ', style: TextStyle(fontFamily: 'Cairo')));

        var docs = snapshot.data!.docs;
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) => (doc.data() as Map<String, dynamic>)['name'].toString().toLowerCase().contains(_searchQuery)).toList();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final productId = docs[index].id;
            final String name = data['name'] ?? 'غير معروف';
            final int currentStock = int.tryParse((data['stockQuantity'] ?? 0).toString()) ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(Icons.inventory_2, color: Colors.blue.shade700)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('رصيد السيستم: $currentStock', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: brandOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () => _showAuditDialog(productId, name, currentStock),
                      child: const Text('جرد فعلي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
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

  // نافذة الجرد الفعلي (حساب العجز والزيادة أوتوماتيكياً)
  void _showAuditDialog(String productId, String productName, int currentStock) {
    TextEditingController actualStockCtrl = TextEditingController();
    TextEditingController noteCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            int actualStock = int.tryParse(actualStockCtrl.text) ?? currentStock;
            int difference = actualStock - currentStock;
            Color diffColor = difference < 0 ? Colors.red : (difference > 0 ? Colors.green : Colors.grey);
            String diffText = difference < 0 ? 'عجز (${difference.abs()})' : (difference > 0 ? 'زيادة (+$difference)' : 'الرصيد مطابق');

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('جرد: $productName', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 16)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الرصيد الدفتري (السيستم):', style: TextStyle(fontFamily: 'Cairo')), Text('$currentStock', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy))]),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: actualStockCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'الرصيد الفعلي (على الرف)',
                          labelStyle: const TextStyle(fontFamily: 'Cairo'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) => setDialogState((){}), // تحديث العجز اللايف
                      ),
                      const SizedBox(height: 12),
                      if (actualStockCtrl.text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: diffColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(difference < 0 ? Icons.trending_down : (difference > 0 ? Icons.trending_up : Icons.check_circle), color: diffColor, size: 20),
                              const SizedBox(width: 8),
                              Text(diffText, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: diffColor)),
                            ],
                          ),
                        ),
                      if (difference != 0) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteCtrl,
                          decoration: InputDecoration(
                            hintText: difference < 0 ? 'سبب العجز (مثال: تالف/مفقود)' : 'سبب الزيادة (مثال: خطأ إدخال سابق)',
                            hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: brandOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () {
                      if (actualStockCtrl.text.isNotEmpty) {
                        _processInventoryAdjustment(productId, productName, currentStock, actualStock, difference, noteCtrl.text);
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('تسوية وحفظ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                  )
                ],
              ),
            );
          }
      ),
    );
  }

  // معالجة الجرد وحفظ التسوية في الفايربيز
  Future<void> _processInventoryAdjustment(String productId, String name, int oldStock, int newStock, int diff, String note) async {
    if (diff == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرصيد مطابق، لا يوجد تسوية مطلوبة.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
      return;
    }

    try {
      WriteBatch batch = _firestore.batch();

      // 1. تحديث رصيد المنتج الفعلي
      DocumentReference productRef = _firestore.collection('products').doc(productId);
      batch.update(productRef, {'stockQuantity': newStock});

      // 2. تسجيل حركة تسوية في سجل الجرد
      DocumentReference auditRef = _firestore.collection('inventory_audits').doc();
      batch.set(auditRef, {
        'productId': productId,
        'productName': name,
        'oldStock': oldStock,
        'newStock': newStock,
        'difference': diff, // لو سالب يبقى عجز، لو موجب يبقى زيادة
        'note': note.isEmpty ? (diff < 0 ? 'عجز جرد' : 'زيادة جرد') : note,
        'type': diff < 0 ? 'loss' : 'gain',
        'date': FieldValue.serverTimestamp(),
      });

      // 3. التسميع المحاسبي (لو عجز، يُسجل كمصروف/خسارة بضاعة)
      // (هنكملها بالتفصيل في الخطوة الجاية بس جهزناها هنا)

      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل التسوية وتحديث الرصيد بنجاح.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
    }
  }


  // =====================================================================
  // 2. التاب الثاني: تقييم رأس المال (Valuation) (مكان فارغ سيتم برمجته)
  // =====================================================================
  // =====================================================================
  // 2. التاب الثاني: تقييم رأس المال (Valuation)
  // =====================================================================
  // =====================================================================
  // 2. التاب الثاني: تقييم رأس المال (Valuation)
  // =====================================================================
  Widget _buildValuationTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('المخزن فارغ', style: TextStyle(fontFamily: 'Cairo')));

        double totalCapital = 0.0;
        int totalPhysicalItems = 0;
        List<Map<String, dynamic>> valuedProducts = [];

        // حسابات التقييم المالي
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          int stock = int.tryParse((data['stockQuantity'] ?? 0).toString()) ?? 0;
          double price = double.tryParse((data['price'] ?? 0).toString()) ?? 0.0;

          // شلنا شرط (المخزون أكبر من صفر) عشان نعرض كل الأصناف الـ 11
          double itemTotalValue = stock > 0 ? (stock * price) : 0.0;
          totalCapital += itemTotalValue;

          if (stock > 0) {
            totalPhysicalItems += stock;
          }

          valuedProducts.add({
            'name': data['name'] ?? 'غير معروف',
            'stock': stock,
            'price': price,
            'totalValue': itemTotalValue,
          });
        }

        // ترتيب المنتجات حسب القيمة الأعلى
        valuedProducts.sort((a, b) => b['totalValue'].compareTo(a['totalValue']));

        return Column(
          children: [
            // كارت إجمالي رأس المال
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryNavy, const Color(0xFF1B2A47)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: primaryNavy.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  const Text('إجمالي قيمة البضاعة في المخزن', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('${totalCapital.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('إجمالي القطع', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 12)),
                          Text('$totalPhysicalItems قطعة', style: TextStyle(fontFamily: 'Cairo', color: brandOrange, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('عدد الأصناف', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 12)),
                          Text('${valuedProducts.length} صنف', style: const TextStyle(fontFamily: 'Cairo', color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  )
                ],
              ),
            ),

            // قائمة تفصيلية بالتقييم لكل منتج
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: valuedProducts.length,
                itemBuilder: (context, index) {
                  final item = valuedProducts[index];
                  bool isZeroStock = item['stock'] <= 0;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isZeroStock ? Colors.red.shade200 : Colors.grey.shade200)),
                    child: ListTile(
                      leading: CircleAvatar(
                          backgroundColor: isZeroStock ? Colors.red.shade50 : Colors.green.shade50,
                          child: Icon(isZeroStock ? Icons.warning_amber_rounded : Icons.monetization_on_rounded, color: isZeroStock ? Colors.red : Colors.green.shade700)
                      ),
                      title: Text(item['name'], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                          isZeroStock ? 'رصيد صفر (نفدت الكمية)' : '${item['stock']} قطعة × ${item['price']} ج.م',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isZeroStock ? Colors.red : Colors.grey)
                      ),
                      trailing: Text('${item['totalValue'].toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 14)),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // =====================================================================
  // 3. التاب الثالث: سجل التوالف والهالك (Spoilage)
  // =====================================================================
  Widget _buildSpoilageTab() {
    return StreamBuilder<QuerySnapshot>(
      // بنجيب حركات الجرد اللي نوعها "عجز / loss"
      stream: _firestore.collection('inventory_audits').where('type', isEqualTo: 'loss').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 60, color: Colors.green.shade300),
                const SizedBox(height: 12),
                const Text('المخزن سليم، لا يوجد سجل توالف أو عجز.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        // سحب البيانات وترتيبها زمنياً (من الأحدث للأقدم) محلياً لتجنب مشاكل الـ Index في فايربيز
        var docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          Timestamp tA = (a.data() as Map<String, dynamic>)['date'] ?? Timestamp.now();
          Timestamp tB = (b.data() as Map<String, dynamic>)['date'] ?? Timestamp.now();
          return tB.compareTo(tA);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String productName = data['productName'] ?? 'منتج غير معروف';
            final int difference = data['difference'] ?? 0;
            final String note = data['note'] ?? 'عجز جرد';

            DateTime date = DateTime.now();
            if (data['date'] != null) date = (data['date'] as Timestamp).toDate();
            String formattedDate = '${date.day}/${date.month}/${date.year}';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.red.shade100)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.red.shade50, child: const Icon(Icons.delete_sweep_rounded, color: Colors.red)),
                title: Text(productName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('السبب: $note', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade800)),
                    Text('التاريخ: $formattedDate', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text('عجز: ${difference.abs()}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}