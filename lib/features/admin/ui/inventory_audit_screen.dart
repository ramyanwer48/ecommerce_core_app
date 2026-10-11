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
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    if (value == value.truncateToDouble()) {
      return value.truncate().toString();
    }
    return value.toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  // 🌟 الرسالة الجديدة: (أظرف، أسرع، في المنتصف، وتختفي تلقائياً)
  void _showFastCenterMessage(BuildContext context, bool isSuccess, String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black12, // لون خلفية خفيف جداً عشان متكونش مزعجة
      barrierDismissible: true,
      builder: (ctx) {
        // إغلاق تلقائي بعد ثانية وربع للسرعة
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (ctx.mounted && Navigator.canPop(ctx)) {
            Navigator.pop(ctx);
          }
        });

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSuccess ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                      color: isSuccess ? Colors.green : Colors.red,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('إدارة المخزون وتقييم الأصول', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: false,
            labelColor: brandOrange,
            unselectedLabelColor: Colors.white70,
            indicatorColor: brandOrange,
            indicatorWeight: 4,
            labelPadding: EdgeInsets.zero,
            tabs: const [
              Tab(icon: Icon(Icons.pending_actions_rounded), child: Text('الاعتمادات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12))),
              Tab(icon: Icon(Icons.fact_check_rounded), child: Text('تعديل سريع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12))),
              Tab(icon: Icon(Icons.account_balance_wallet_rounded), child: Text('التقييم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12))),
              Tab(icon: Icon(Icons.history_edu_rounded), child: Text('السجل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              color: primaryNavy,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPendingAuditsTab(),
                  _buildReconciliationTab(),
                  _buildValuationTab(),
                  _buildSpoilageTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // 1. التاب الأول: الاعتمادات المعلقة
  // =====================================================================
  Widget _buildPendingAuditsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('pending_audits').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(fontFamily: 'Cairo', color: Colors.red)));
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('لا توجد طلبات جرد معلقة.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        var docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          Timestamp tA = (a.data() as Map<String, dynamic>)['timestamp'] ?? Timestamp.now();
          Timestamp tB = (b.data() as Map<String, dynamic>)['timestamp'] ?? Timestamp.now();
          return tB.compareTo(tA);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String productName = data['productName'] ?? 'غير معروف';
            final int systemStock = data['systemStock'] ?? 0;
            final int goodStock = data['actualGoodStock'] ?? 0;
            final int damagedStock = data['damagedStock'] ?? 0;
            final String? photoUrl = data['photoUrl'];
            final String submittedBy = data['submittedBy'] ?? 'موظف مجهول';

            final int totalActual = goodStock + damagedStock;
            final int difference = totalActual - systemStock;

            Color diffColor = difference < 0 ? Colors.red : (difference > 0 ? Colors.green : Colors.blue);
            String diffText = difference < 0 ? 'عجز (${difference.abs()})' : (difference > 0 ? 'زيادة (+$difference)' : 'مطابق');

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
              elevation: 4,
              shadowColor: Colors.black12,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('جرد: $productName', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: diffColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: diffColor.withOpacity(0.5))),
                          child: Text(diffText, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: diffColor, fontSize: 12)),
                        )
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('أمين المخزن: $submittedBy', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildStockInfoCard('السيستم', systemStock.toString(), Colors.blue)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStockInfoCard('سليم (فعلي)', goodStock.toString(), Colors.green)),
                        if (damagedStock > 0) ...[
                          const SizedBox(width: 8),
                          Expanded(child: _buildStockInfoCard('تالف (فعلي)', damagedStock.toString(), Colors.red)),
                        ]
                      ],
                    ),

                    if (damagedStock > 0 && photoUrl != null) ...[
                      const SizedBox(height: 16),
                      const Text('صورة البضاعة التالفة:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showImageDialog(context, photoUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            photoUrl,
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 160, width: double.infinity,
                                color: Colors.grey.shade100,
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                            onPressed: () => _handleAuditAction(doc.id, 'rejected', data),
                            child: const Text('رفض وإعادة جرد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: brandOrange),
                            onPressed: () => _handleAuditAction(doc.id, 'approved', data),
                            child: const Text('اعتماد وتحديث', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                          ),
                        ),
                      ],
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

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(height: 300, color: Colors.white, child: const Center(child: CircularProgressIndicator()));
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStockInfoCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: color, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  Future<void> _handleAuditAction(String requestId, String action, Map<String, dynamic> data) async {
    try {
      WriteBatch batch = _firestore.batch();
      DocumentReference requestRef = _firestore.collection('pending_audits').doc(requestId);
      batch.update(requestRef, {'status': action, 'actionDate': FieldValue.serverTimestamp()});

      if (action == 'approved') {
        final String productId = data['productId'];
        final int goodStock = data['actualGoodStock'] ?? 0;
        final int systemStock = data['systemStock'] ?? 0;
        final int damagedStock = data['damagedStock'] ?? 0;
        final int difference = (goodStock + damagedStock) - systemStock;

        DocumentReference productRef = _firestore.collection('products').doc(productId);
        batch.update(productRef, {
          'stockQuantity': goodStock,
          'damagedQuantity': FieldValue.increment(damagedStock)
        });

        DocumentReference auditRef = _firestore.collection('inventory_audits').doc();
        batch.set(auditRef, {
          'productId': productId,
          'productName': data['productName'],
          'oldStock': systemStock,
          'newStock': goodStock,
          'difference': difference,
          'damagedStock': damagedStock,
          'note': damagedStock > 0 ? 'تم اعتماد العجز/التالف بصورة' : (difference < 0 ? 'عجز معتمد' : 'زيادة معتمدة'),
          'type': (difference < 0 || damagedStock > 0) ? 'loss' : 'gain',
          'date': FieldValue.serverTimestamp(),
          'submittedBy': data['submittedBy'],
        });
      }

      await batch.commit();

      // 🌟 استدعاء الدالة الجديدة السريعة في المنتصف بدلاً من الـ SnackBar القديم
      if (mounted) {
        _showFastCenterMessage(
            context,
            action == 'approved',
            action == 'approved' ? 'تم اعتماد الجرد بنجاح' : 'تم رفض الجرد وإعادته للموظف'
        );
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
    }
  }

  // =====================================================================
  // 2. التاب الثاني: تعديل سريع للمدير
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

            final String? imageUrl = data['imageUrl'] ?? data['image'];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                      child: (imageUrl != null && imageUrl.isNotEmpty)
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Icon(Icons.image_not_supported, color: Colors.blue.shade300)),
                      )
                          : Icon(Icons.inventory_2_rounded, color: Colors.blue.shade700),
                    ),
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
                      onPressed: () => _showDirectAuditBottomSheet(productId, name, currentStock),
                      child: const Text('تعديل يـدوي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
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

  void _showDirectAuditBottomSheet(String productId, String productName, int currentStock) {
    TextEditingController actualStockCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setSheetState) {
            int actualStock = int.tryParse(actualStockCtrl.text) ?? currentStock;
            int difference = actualStock - currentStock;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 16),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 16),
                      Text('تعديل رصيد سريع: $productName', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 16)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: actualStockCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'الرصيد الصحيح الجديد',
                          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 2)),
                        ),
                        onChanged: (val) => setSheetState((){}),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: brandOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () {
                            if (actualStockCtrl.text.isNotEmpty && difference != 0) {
                              FocusManager.instance.primaryFocus?.unfocus();
                              _firestore.collection('products').doc(productId).update({'stockQuantity': actualStock});
                              _firestore.collection('inventory_audits').doc().set({
                                'productId': productId, 'productName': productName, 'oldStock': currentStock, 'newStock': actualStock, 'difference': difference, 'note': 'تعديل إداري مباشر من المدير', 'type': difference < 0 ? 'loss' : 'gain', 'date': FieldValue.serverTimestamp(),
                              });
                              Navigator.pop(ctx);
                              // 🌟 استخدام الدالة السريعة هنا أيضاً
                              _showFastCenterMessage(context, true, 'تم تحديث الرصيد يدوياً بنجاح');
                            }
                          },
                          child: const Text('تحديث الرصيد يدوياً', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
      ),
    );
  }

  // =====================================================================
  // 3. التاب الثالث: تقييم رأس المال
  // =====================================================================
  Widget _buildValuationTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('المخزن فارغ', style: TextStyle(fontFamily: 'Cairo')));

        double totalGoodValue = 0.0;
        double totalDamagedValue = 0.0;

        List<Map<String, dynamic>> valuedProducts = [];

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          int goodStock = int.tryParse((data['stockQuantity'] ?? 0).toString()) ?? 0;
          int damagedStock = int.tryParse((data['damagedQuantity'] ?? 0).toString()) ?? 0;

          double price = double.tryParse((data['price'] ?? data['costPrice'] ?? 0).toString()) ?? 0.0;

          double goodValue = goodStock > 0 ? (goodStock * price) : 0.0;
          double damagedValue = damagedStock > 0 ? (damagedStock * price) : 0.0;

          totalGoodValue += goodValue;
          totalDamagedValue += damagedValue;

          if (goodStock > 0 || damagedStock > 0) {
            valuedProducts.add({'name': data['name'] ?? 'غير معروف', 'goodStock': goodStock, 'damagedStock': damagedStock, 'price': price, 'totalValue': (goodValue + damagedValue)});
          }
        }

        valuedProducts.sort((a, b) => b['totalValue'].compareTo(a['totalValue']));
        double totalCapital = totalGoodValue + totalDamagedValue;

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryNavy,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: primaryNavy.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  const Text('إجمالي قيمة البضاعة (سليم + تالف)', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13)),
                  Text('${_formatNumber(totalCapital)} ج.م', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('قيمة السليم', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('${_formatNumber(totalGoodValue)} ج.م', style: const TextStyle(fontFamily: 'Cairo', color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 35, color: Colors.white24),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('قيمة التالف', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('${_formatNumber(totalDamagedValue)} ج.م', style: const TextStyle(fontFamily: 'Cairo', color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: valuedProducts.length,
                itemBuilder: (context, index) {
                  final item = valuedProducts[index];
                  bool hasDamage = item['damagedStock'] > 0;
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
                    child: ListTile(
                      title: Text(item['name'], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('سليم: ${item['goodStock']} | السعر: ${_formatNumber(item['price'])}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                          if (hasDamage) Text('تالف بالمخزن: ${item['damagedStock']} قطعة', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      trailing: Text('${_formatNumber(item['totalValue'])} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 14)),
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
  // 4. التاب الرابع: السجل
  // =====================================================================
  Widget _buildSpoilageTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('inventory_audits').orderBy('date', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا يوجد سجل حركات حتى الآن.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 16)));
        }

        var docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String productName = data['productName'] ?? 'منتج غير معروف';
            final int difference = data['difference'] ?? 0;
            final String note = data['note'] ?? '';
            final String type = data['type'] ?? 'loss';

            DateTime date = DateTime.now();
            if (data['date'] != null) date = (data['date'] as Timestamp).toDate();

            String amPm = date.hour >= 12 ? 'م' : 'ص';
            int hour12 = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
            String formattedDate = '${date.year}/${date.month}/${date.day} - $hour12:${date.minute.toString().padLeft(2, '0')} $amPm';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: type == 'loss' ? Colors.red.shade100 : Colors.green.shade100)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: type == 'loss' ? Colors.red.shade50 : Colors.green.shade50, child: Icon(type == 'loss' ? Icons.trending_down : Icons.trending_up, color: type == 'loss' ? Colors.red : Colors.green)),
                title: Text(productName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('البيان: $note', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade800)),
                    Text('التاريخ: $formattedDate', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: type == 'loss' ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text('${difference.abs()}', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: type == 'loss' ? Colors.red : Colors.green)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}