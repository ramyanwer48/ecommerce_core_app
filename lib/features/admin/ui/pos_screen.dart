import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/pdf_invoice_service.dart';
import '../../invoices/data/models/invoice_model.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  String _customerName = 'عميل نقدي (مقر الشركة)';
  String _customerId = 'CASH_CUSTOMER';

  final List<Map<String, dynamic>> _cartItems = [];
  double _discount = 0.0;

  // 🚀 متغيرات التجميد (لتحديد حالة الفاتورة)
  bool _isSaved = false;
  InvoiceModel? _savedInvoice;

  double get _subtotal => _cartItems.fold(0, (sum, item) => sum + (item['price'] * item['qty']));
  double get _total => _subtotal - _discount;

  // دالة تصفير الكاشير لفاتورة جديدة
  void _startNewInvoice() {
    setState(() {
      _cartItems.clear();
      _discount = 0.0;
      _customerName = 'عميل نقدي (مقر الشركة)';
      _customerId = 'CASH_CUSTOMER';
      _isSaved = false;
      _savedInvoice = null;
    });
  }

  // 1️⃣ شيت اختيار العميل
  void _showCustomersSheet() {
    if (_isSaved) return; // منع تغيير العميل إذا كانت الفاتورة محفوظة

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.only(top: 16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              const Text('اختر العميل (للتسجيل في حسابه)', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.person, color: Colors.white)),
                title: const Text('عميل نقدي (مقر الشركة)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                subtitle: const Text('للزوار غير المسجلين', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                onTap: () {
                  setState(() { _customerName = 'عميل نقدي (مقر الشركة)'; _customerId = 'CASH_CUSTOMER'; });
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('customers').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا يوجد عملاء مسجلين', style: TextStyle(fontFamily: 'Cairo')));

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: primaryNavy.withOpacity(0.1), child: Icon(Icons.person_outline, color: primaryNavy)),
                          title: Text(data['name'] ?? 'بدون اسم', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          subtitle: Text(data['phone'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                          onTap: () {
                            setState(() {
                              _customerName = data['name'] ?? 'بدون اسم';
                              _customerId = doc.id;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2️⃣ شيت المنتجات
  void _showProductsSheet() {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(color: Color(0xFFF5F7FA), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(
                  children: [
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 16),
                    const Text('اختر المنتج', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        onChanged: (val) => setSheetState(() => searchQuery = val.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'ابحث باسم المنتج...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),

                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('products').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد منتجات مسجلة بالمخزن.', style: TextStyle(fontFamily: 'Cairo')));

                          var docs = snapshot.data!.docs;
                          if (searchQuery.isNotEmpty) {
                            docs = docs.where((doc) {
                              String name = ((doc.data() as Map<String, dynamic>)['name'] ?? '').toString().toLowerCase();
                              return name.contains(searchQuery);
                            }).toList();
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              var doc = docs[index];
                              var data = doc.data() as Map<String, dynamic>;
                              String name = data['name'] ?? 'منتج غير معروف';
                              double price = double.tryParse((data['price'] ?? 0).toString()) ?? 0.0;
                              int stock = int.tryParse((data['stockQuantity'] ?? 0).toString()) ?? 0;

                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                                child: ListTile(
                                  leading: CircleAvatar(backgroundColor: brandOrange.withOpacity(0.1), child: Icon(Icons.inventory_2, color: brandOrange)),
                                  title: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('المخزون: $stock', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: stock > 0 ? Colors.green : Colors.red)),
                                  trailing: Text('$price ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 15)),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _showQuantityDialog(doc.id, name, price);
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
      ),
    );
  }

  // 3️⃣ نافذة إدخال الكمية
  void _showQuantityDialog(String productId, String productName, double price) {
    TextEditingController qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(productName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('سعر الوحدة: ', style: TextStyle(fontFamily: 'Cairo')),
                    Text('$price ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'الكمية المطلوبة',
                  labelStyle: const TextStyle(fontFamily: 'Cairo'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                int qty = int.tryParse(qtyCtrl.text) ?? 1;
                if (qty > 0) {
                  setState(() {
                    int existingIndex = _cartItems.indexWhere((item) => item['id'] == productId);
                    if (existingIndex >= 0) {
                      _cartItems[existingIndex]['qty'] += qty;
                    } else {
                      _cartItems.add({
                        'id': productId,
                        'name': productName,
                        'price': price,
                        'qty': qty,
                      });
                    }
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('إضافة للفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  // 🚀 الشاشة المنبثقة للطباعة والمشاركة
  void _showPostSaveActions(InvoiceModel invoice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 12),
              const Text('تم حفظ الفاتورة بنجاح!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
            ],
          ),
          content: const Text('تم تجميد الفاتورة لحماية الحسابات. اختر الإجراء التالي:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.print),
                  label: const Text('معاينة وطباعة (PDF)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    PdfInvoiceService.directPrintInvoice(invoice);
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.share),
                  label: const Text('مشاركة (واتساب)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    PdfInvoiceService.shareInvoicePdf(invoice);
                  },
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700, padding: const EdgeInsets.symmetric(vertical: 12)),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('إغلاق وبدء فاتورة جديدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startNewInvoice(); // 👈 تصفير الكاشير هنا
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // دالة الحفظ
  Future<void> _saveInvoice() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الفاتورة فارغة! أضف منتجات أولاً', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      return;
    }

    String orderId = _firestore.collection('orders').doc().id;
    String invoiceNum = 'POS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    String currentUserId = _auth.currentUser?.uid ?? '';

    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول كمسؤول أولاً', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));

    try {
      WriteBatch batch = _firestore.batch();

      DocumentReference orderRef = _firestore.collection('orders').doc(orderId);
      batch.set(orderRef, {
        'id': orderId,
        'userId': currentUserId,
        'orderNumber': invoiceNum,
        'customerName': _customerName,
        'phone': 'عميل مقر',
        'address': 'مبيعات مباشرة (POS)',
        'items': _cartItems.map((item) => {
          'productId': item['id'],
          'productName': item['name'],
          'name': item['name'],
          'price': item['price'],
          'quantity': item['qty'],
        }).toList(),
        'totalPrice': _total,
        'subtotal': _subtotal,
        'discountAmount': _discount,
        'paymentMethod': 'كاش',
        'status': 'Delivered',
        'orderSource': 'POS',
        'createdAt': FieldValue.serverTimestamp(),
      });

      DocumentReference saleRef = _firestore.collection('ledger_entries').doc('sale_$orderId');
      batch.set(saleRef, {
        'partnerId': _customerId,
        'partnerName': _customerName,
        'type': 'sale',
        'amount': _total,
        'date': FieldValue.serverTimestamp(),
        'note': 'مبيعات كاشير (POS) فاتورة: $invoiceNum',
      });

      DocumentReference receiptRef = _firestore.collection('ledger_entries').doc('receipt_$orderId');
      batch.set(receiptRef, {
        'partnerId': _customerId,
        'partnerName': _customerName,
        'type': 'receipt',
        'amount': _total,
        'date': FieldValue.serverTimestamp(),
        'note': 'تحصيل نقدي أوتوماتيكي (POS)',
      });

      for (var item in _cartItems) {
        DocumentReference productRef = _firestore.collection('products').doc(item['id']);
        batch.update(productRef, {
          'stockQuantity': FieldValue.increment(-item['qty'])
        });
      }

      await batch.commit();
      Navigator.pop(context); // إخفاء اللودينج

      final invoice = InvoiceModel(
        id: orderId,
        invoiceNumber: invoiceNum,
        partnerId: _customerId,
        date: DateTime.now(),
        type: 'sale',
        partnerName: _customerName,
        status: 'paid',
        subtotal: _subtotal,
        discountAmount: _discount,
        totalAmount: _total,
        items: _cartItems.map((item) => InvoiceItemModel(
          productId: item['id'],
          productName: item['name'],
          quantity: item['qty'],
          unitPrice: item['price'],
        )).toList(),
      );

      // 🚀 تفعيل التجميد
      setState(() {
        _isSaved = true;
        _savedInvoice = invoice;
      });

      _showPostSaveActions(invoice);

    } catch (e) {
      Navigator.pop(context);
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('كاشير المبيعات (POS)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: primaryNavy,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            // كارت اختيار العميل
            GestureDetector(
              onTap: _showCustomersSheet, // 👈 لن يعمل إذا كانت الفاتورة متجمدة
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.green.shade50, child: Icon(Icons.person, color: Colors.green.shade600)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('العميل الحالي:', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                          Text(_customerName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D1B2A))),
                        ],
                      ),
                    ),
                    if (!_isSaved) Icon(Icons.edit, size: 20, color: brandOrange), // 👈 يختفي إذا تجمدت
                    if (_isSaved) const Icon(Icons.lock, size: 20, color: Colors.grey), // 👈 قفل التجميد
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // قائمة الفاتورة
            Expanded(
              child: _cartItems.isEmpty
                  ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('لم يتم إضافة منتجات للفاتورة بعد', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade500, fontSize: 16)),
                    ],
                  )
              )
                  : ListView.builder(
                itemCount: _cartItems.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (context, index) {
                  final item = _cartItems[index];
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(item['name'], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('الكمية: ${item['qty']}  ×  ${item['price']} ج.م', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700)),
                      trailing: Text('${(item['qty'] * item['price']).toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 15)),
                      // 👈 زرار الحذف يختفي إذا الفاتورة اتجمدت
                      leading: _isSaved ? null : IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22), onPressed: () => setState(() => _cartItems.removeAt(index))),
                    ),
                  );
                },
              ),
            ),

            // شريط الإجماليات وأزرار التحكم (الديناميكية)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
              child: SafeArea(
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي الفرعي:', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)), Text('${_subtotal.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))]),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الخصم:', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)), Text('${_discount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold))]),
                    const Divider(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الصافي (المطلوب دفعه):', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)), Text('${_total.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: primaryNavy))]),
                    const SizedBox(height: 20),

                    // 🚀 زراير الكاشير تتغير كلياً لو الفاتورة محفوظة (تجميد)
                    if (!_isSaved)
                      Row(
                        children: [
                          Expanded(
                              child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: primaryNavy, side: BorderSide(color: primaryNavy), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  onPressed: _showProductsSheet,
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: const Text('إضافة صنف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))
                              )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: brandOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  onPressed: _saveInvoice,
                                  icon: const Icon(Icons.save),
                                  label: const Text('دفع وحفظ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16))
                              )
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                              child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: primaryNavy, side: BorderSide(color: primaryNavy), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  onPressed: () => _showPostSaveActions(_savedInvoice!), // 👈 استدعاء نافذة الطباعة تاني
                                  icon: const Icon(Icons.print),
                                  label: const Text('طباعة ومشاركة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))
                              )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  onPressed: _startNewInvoice, // 👈 تصفير وفتح فاتورة جديدة
                                  icon: const Icon(Icons.add_shopping_cart),
                                  label: const Text('بدء فاتورة جديدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16))
                              )
                          ),
                        ],
                      )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}