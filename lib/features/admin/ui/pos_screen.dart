import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String _searchQuery = '';

  final List<Map<String, dynamic>> _cartItems = [];
  final double _discount = 0.0;

  double get _subtotal => _cartItems.fold(0, (sum, item) => sum + (item['price'] * item['qty']));
  double get _total => _subtotal - _discount;

  void _showCustomSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startNewInvoice() {
    setState(() {
      _cartItems.clear();
      _customerName = 'عميل نقدي (مقر الشركة)';
      _customerId = 'CASH_CUSTOMER';
    });
  }

  void _addToCart(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String id = doc.id;
    String name = data['name'] ?? 'منتج';
    double price = double.tryParse((data['price'] ?? 0).toString()) ?? 0.0;
    int stock = int.tryParse((data['stockQuantity'] ?? 0).toString()) ?? 0;

    if (stock <= 0) {
      _showCustomSnackBar('عفواً، هذا المنتج نفد من المخزن!', true);
      return;
    }

    setState(() {
      int index = _cartItems.indexWhere((item) => item['id'] == id);
      if (index >= 0) {
        if (_cartItems[index]['qty'] < stock) {
          _cartItems[index]['qty']++;
        } else {
          _showCustomSnackBar('الكمية المطلوبة تتجاوز رصيد المخزن!', true);
        }
      } else {
        _cartItems.add({'id': id, 'name': name, 'price': price, 'qty': 1, 'stock': stock});
      }
    });
  }

  Future<void> _saveInvoice(BuildContext sheetContext) async {
    if (_cartItems.isEmpty) return;

    String orderId = _firestore.collection('orders').doc().id;
    String invoiceNum = 'POS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    String currentUserId = _auth.currentUser?.uid ?? '';

    if (currentUserId.isEmpty) {
      _showCustomSnackBar('يجب تسجيل الدخول أولاً', true);
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
        'address': 'مبيعات مباشرة (مقر الشركة)',
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
        'orderType': 'pos',
        'createdAt': FieldValue.serverTimestamp(),
      });

      DocumentReference saleRef = _firestore.collection('ledger_entries').doc('sale_$orderId');
      batch.set(saleRef, {
        'partnerId': _customerId,
        'partnerName': _customerName,
        'type': 'sale',
        'amount': _total,
        'date': FieldValue.serverTimestamp(),
        'note': 'مبيعات مباشرة (الشركة) - $invoiceNum',
      });

      DocumentReference receiptRef = _firestore.collection('ledger_entries').doc('receipt_$orderId');
      batch.set(receiptRef, {
        'partnerId': _customerId,
        'partnerName': _customerName,
        'type': 'receipt',
        'amount': _total,
        'date': FieldValue.serverTimestamp(),
        'note': 'تحصيل نقدي أوتوماتيكي (مبيعات الشركة)',
      });

      for (var item in _cartItems) {
        DocumentReference productRef = _firestore.collection('products').doc(item['id']);
        batch.update(productRef, {'stockQuantity': FieldValue.increment(-item['qty'])});
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(sheetContext);
        _startNewInvoice();
        _showCustomSnackBar('تم إتمام البيع بنجاح 🚀', false);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showCustomSnackBar('حدث خطأ: $e', true);
    }
  }

  // الشيت السريع المدمج للعملاء
  void _showCustomersSheet(StateSetter parentSetState) {
    bool isAddingNew = false;
    bool isSaving = false;
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setLocalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(
                  children: [
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 16),
                    Text(isAddingNew ? 'إضافة عميل جديد' : 'اختر العميل', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),

                    if (isAddingNew) ...[
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              TextField(
                                controller: nameCtrl,
                                autofocus: true,
                                decoration: InputDecoration(
                                  labelText: 'اسم العميل *',
                                  labelStyle: const TextStyle(fontFamily: 'Cairo'),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'رقم الهاتف (اختياري)',
                                  labelStyle: const TextStyle(fontFamily: 'Cairo'),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () => setLocalState(() => isAddingNew = false),
                                      child: const Text('رجوع للقائمة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: brandOrange, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      onPressed: isSaving ? null : () async {
                                        if (nameCtrl.text.trim().isEmpty) {
                                          _showCustomSnackBar('يرجى إدخال اسم العميل', true);
                                          return;
                                        }

                                        setLocalState(() => isSaving = true);

                                        try {
                                          DocumentReference newCustomer = await _firestore.collection('customers').add({
                                            'name': nameCtrl.text.trim(),
                                            'phone': phoneCtrl.text.trim(),
                                            'balance': 0.0,
                                            'createdAt': FieldValue.serverTimestamp(),
                                          });

                                          if (mounted) {
                                            setState(() {
                                              _customerName = nameCtrl.text.trim();
                                              _customerId = newCustomer.id;
                                            });
                                            parentSetState(() {});
                                            Navigator.pop(ctx);
                                            _showCustomSnackBar('تم اختيار العميل بنجاح', false);
                                          }
                                        } catch (e) {
                                          setLocalState(() => isSaving = false);
                                          _showCustomSnackBar('حدث خطأ أثناء الإضافة', true);
                                        }
                                      },
                                      child: isSaving
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Text('حفظ واختيار', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      )
                    ] else ...[
                      ListTile(
                        leading: const Icon(Icons.person, color: Colors.green),
                        title: const Text('عميل نقدي (مقر الشركة)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        onTap: () {
                          setState(() { _customerName = 'عميل نقدي (مقر الشركة)'; _customerId = 'CASH_CUSTOMER'; });
                          parentSetState(() {});
                          Navigator.pop(ctx);
                        },
                      ),
                      const Divider(),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _firestore.collection('customers').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            var docs = snapshot.data!.docs;
                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                var doc = docs[index];
                                return ListTile(
                                  title: Text(doc['name'], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                  subtitle: Text(doc['phone'] ?? ''),
                                  onTap: () {
                                    setState(() { _customerName = doc['name']; _customerId = doc.id; });
                                    parentSetState(() {});
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 🚀 الزرار تم نقله للأسفل مع تثبيته ليكون مرئي دائماً
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: primaryNavy.withOpacity(0.05),
                            foregroundColor: primaryNavy,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        onPressed: () => setLocalState(() => isAddingNew = true),
                        icon: const Icon(Icons.person_add),
                        label: const Text('إضافة عميل جديد للسيستم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCartAndCheckoutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(
                  children: [
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 16),
                    const Text('مراجعة السلة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),

                    // 🚀 الكارت كله بقى قابل للضغط لفتح الشيت السريع
                    InkWell(
                      onTap: () => _showCustomersSheet(setSheetState),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(backgroundColor: primaryNavy.withOpacity(0.1), child: Icon(Icons.person, color: primaryNavy)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('العميل الحالي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                                  Text(_customerName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black, fontSize: 15)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),

                    Expanded(
                      child: _cartItems.isEmpty
                          ? const Center(child: Text('السلة فارغة', style: TextStyle(fontFamily: 'Cairo')))
                          : ListView.builder(
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          final item = _cartItems[index];
                          return ListTile(
                            title: Text(item['name'], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('${item['price']} ج.م', style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () {
                                    setSheetState(() {
                                      setState(() {
                                        if (item['qty'] > 1) {
                                          item['qty']--;
                                        } else {
                                          _cartItems.removeAt(index);
                                          if (_cartItems.isEmpty) Navigator.pop(sheetContext);
                                        }
                                      });
                                    });
                                  },
                                ),
                                Text('${item['qty']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  onPressed: () {
                                    if (item['qty'] < item['stock']) {
                                      setSheetState(() => setState(() => item['qty']++));
                                    } else {
                                      _showCustomSnackBar('لا يوجد رصيد كافي في المخزن', true);
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('المطلوب دفعه:', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)), Text('${_total.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: primaryNavy))]),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: brandOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                onPressed: () => _saveInvoice(sheetContext),
                                icon: const Icon(Icons.point_of_sale),
                                label: const Text('دفع وإتمام البيع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                  ],
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
          title: const Text('المبيعات المباشرة (مقر الشركة)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
          backgroundColor: primaryNavy,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(icon: const Icon(Icons.cleaning_services_rounded), onPressed: _startNewInvoice, tooltip: 'تفريغ الفاتورة'),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: primaryNavy,
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('المخزن فارغ', style: TextStyle(fontFamily: 'Cairo')));

                  var docs = snapshot.data!.docs;
                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((doc) => ((doc.data() as Map<String, dynamic>)['name'] ?? '').toString().toLowerCase().contains(_searchQuery)).toList();
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var doc = docs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      String name = data['name'] ?? 'منتج';
                      String imageUrl = data['imageUrl'] ?? '';
                      double price = double.tryParse((data['price'] ?? 0).toString()) ?? 0.0;
                      int stock = int.tryParse((data['stockQuantity'] ?? 0).toString()) ?? 0;

                      int qtyInCart = _cartItems.firstWhere((item) => item['id'] == doc.id, orElse: () => {'qty': 0})['qty'];

                      return InkWell(
                        onTap: () => _addToCart(doc),
                        borderRadius: BorderRadius.circular(16),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: qtyInCart > 0 ? brandOrange : Colors.transparent, width: 2)),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: primaryNavy.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: imageUrl.isNotEmpty
                                            ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) => Icon(Icons.image_not_supported, size: 30, color: Colors.grey.shade400),
                                          ),
                                        )
                                            : Icon(Icons.inventory_2, size: 40, color: primaryNavy.withOpacity(0.3)),
                                      ),
                                      if (qtyInCart > 0)
                                        Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundColor: brandOrange,
                                            child: Text('$qtyInCart', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, height: 1.2)),
                                const SizedBox(height: 4),
                                Text('$price ج.م', style: TextStyle(fontFamily: 'Cairo', color: brandOrange, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('المخزون: $stock', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: stock > 0 ? Colors.green : Colors.red)),
                              ],
                            ),
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

        bottomNavigationBar: _cartItems.isEmpty ? null : InkWell(
          onTap: _showCartAndCheckoutSheet,
          child: Container(
            height: 65,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
                color: primaryNavy,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: brandOrange, width: 2.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: Text('${_cartItems.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    const Text('مراجعة السلة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Text('${_total.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}