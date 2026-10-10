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

  String _customerName = 'عميل نقدي (الشركة)';
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
            Icon(isError ? Icons.warning_rounded : Icons.check_circle_rounded, color: isError ? Colors.redAccent : brandOrange, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13))),
          ],
        ),
        backgroundColor: primaryNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isError ? Colors.redAccent : brandOrange, width: 1.5)
        ),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startNewInvoice() {
    setState(() {
      _cartItems.clear();
      _customerName = 'عميل نقدي (الشركة)';
      _customerId = 'CASH_CUSTOMER';
    });
  }

  void _addToCart(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String id = doc.id;
    String name = data['name'] ?? 'منتج';
    double price = double.tryParse((data['price'] ?? 0).toString()) ?? 0.0;
    double cost = double.tryParse((data['costPrice'] ?? 0).toString()) ?? 0.0;
    int stock = int.tryParse((data['stockQuantity'] ?? 0).toString()) ?? 0;

    if (stock <= 0) {
      _showCustomSnackBar('المنتج غير متوفر بالمخزن!', true);
      return;
    }

    setState(() {
      int index = _cartItems.indexWhere((item) => item['id'] == id);
      if (index >= 0) {
        if (_cartItems[index]['qty'] < stock) {
          _cartItems[index]['qty']++;
        } else {
          _showCustomSnackBar('الكمية تتجاوز رصيد المخزن!', true);
        }
      } else {
        _cartItems.add({'id': id, 'name': name, 'price': price, 'cost': cost, 'qty': 1, 'stock': stock});
      }
    });
  }

  void _showCreditAlert(BuildContext context) {
    showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: brandOrange, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: primaryNavy.withOpacity(0.05), shape: BoxShape.circle),
                  child: Icon(Icons.warning_amber_rounded, color: brandOrange, size: 45),
                ),
                const SizedBox(height: 16),
                Text('إجراء غير مسموح', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                const SizedBox(height: 8),
                const Text('لا يمكن تسجيل فاتورة آجلة لعميل نقدي.\nيرجى اختيار عميل مسجل أولاً.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey, height: 1.4)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        )
    );
  }

  Future<void> _saveInvoice(BuildContext sheetContext, double paidAmount, String paymentType) async {
    if (_cartItems.isEmpty) return;
    double remainingAmount = _total - paidAmount;
    double totalCostPrice = _cartItems.fold(0, (sum, item) => sum + (item['cost'] * item['qty']));

    if (remainingAmount > 0 && _customerId == 'CASH_CUSTOMER') {
      _showCreditAlert(sheetContext);
      return;
    }

    String orderId = _firestore.collection('orders').doc().id;
    String invoiceNum = 'POS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    String currentUserId = _auth.currentUser?.uid ?? '';

    if (currentUserId.isEmpty) {
      _showCustomSnackBar('يجب تسجيل الدخول', true);
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => Center(child: CircularProgressIndicator(color: brandOrange)));

    try {
      WriteBatch batch = _firestore.batch();
      DocumentReference orderRef = _firestore.collection('orders').doc(orderId);

      batch.set(orderRef, {
        'id': orderId,
        'userId': currentUserId,
        'orderNumber': invoiceNum,
        'customerName': _customerName,
        'phone': 'عميل مقر',
        'address': 'مبيعات مباشرة (الشركة)',
        'items': _cartItems.map((item) => {
          'productId': item['id'],
          'productName': item['name'],
          'name': item['name'],
          'price': item['price'],
          'costPrice': item['cost'],
          'quantity': item['qty'],
        }).toList(),
        'totalPrice': _total,
        'totalCostPrice': totalCostPrice,
        'subtotal': _subtotal,
        'discountAmount': _discount,
        'paidAmount': paidAmount,
        'remainingAmount': remainingAmount,
        'paymentMethod': paymentType,
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

      if (paidAmount > 0) {
        DocumentReference receiptRef = _firestore.collection('ledger_entries').doc('receipt_$orderId');
        batch.set(receiptRef, {
          'partnerId': _customerId,
          'partnerName': _customerName,
          'type': 'receipt',
          'amount': paidAmount,
          'date': FieldValue.serverTimestamp(),
          'note': 'تحصيل نقدي - $invoiceNum',
        });
      }

      if (remainingAmount > 0 && _customerId != 'CASH_CUSTOMER') {
        DocumentReference customerRef = _firestore.collection('customers').doc(_customerId);
        batch.update(customerRef, {'balance': FieldValue.increment(remainingAmount)});
      }

      for (var item in _cartItems) {
        DocumentReference productRef = _firestore.collection('products').doc(item['id']);
        batch.update(productRef, {'stockQuantity': FieldValue.increment(-item['qty'])});
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(sheetContext);
        _startNewInvoice();
        _showCustomSnackBar('تم إتمام البيع بنجاح', false);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showCustomSnackBar('خطأ: $e', true);
    }
  }

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
                height: MediaQuery.of(context).size.height * 0.70,
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(
                  children: [
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isAddingNew ? 'إضافة عميل جديد' : 'اختر العميل', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                        // 👈 تم توحيد تصميم زر الإغلاق ليكون بإطار أسود وخلفية بيضاء
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.black87, width: 1.2)
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
                          ),
                        )
                      ],
                    ),
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
                                style: const TextStyle(fontFamily: 'Cairo'),
                                decoration: InputDecoration(labelText: 'اسم العميل *', labelStyle: const TextStyle(fontFamily: 'Cairo'), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontFamily: 'Cairo'),
                                decoration: InputDecoration(labelText: 'رقم الهاتف (اختياري)', labelStyle: const TextStyle(fontFamily: 'Cairo'), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                      child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                          onPressed: () => setLocalState(() => isAddingNew = false),
                                          child: const Text('رجوع للقائمة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold))
                                      )
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: brandOrange, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      onPressed: isSaving ? null : () async {
                                        if (nameCtrl.text.trim().isEmpty) { _showCustomSnackBar('يرجى إدخال اسم العميل', true); return; }
                                        setLocalState(() => isSaving = true);
                                        try {
                                          DocumentReference newCustomer = await _firestore.collection('customers').add({
                                            'name': nameCtrl.text.trim(),
                                            'phone': phoneCtrl.text.trim(),
                                            'balance': 0.0,
                                            'createdAt': FieldValue.serverTimestamp(),
                                          });
                                          if (mounted) {
                                            setState(() { _customerName = nameCtrl.text.trim(); _customerId = newCustomer.id; });
                                            parentSetState(() {});
                                            Navigator.pop(ctx);
                                            _showCustomSnackBar('تمت الإضافة', false);
                                          }
                                        } catch (e) {
                                          setLocalState(() => isSaving = false);
                                          _showCustomSnackBar('خطأ أثناء الحفظ', true);
                                        }
                                      },
                                      child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('حفظ واختيار', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
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
                        leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.person, color: Colors.green.shade700)
                        ),
                        title: const Text('عميل نقدي (الشركة)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: () {
                          setState(() { _customerName = 'عميل نقدي (الشركة)'; _customerId = 'CASH_CUSTOMER'; });
                          parentSetState(() {});
                          Navigator.pop(ctx);
                        },
                      ),
                      const Divider(),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _firestore.collection('customers').orderBy('createdAt', descending: true).snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: brandOrange));
                            var docs = snapshot.data!.docs;
                            if (docs.isEmpty) {
                              return const Center(child: Text('لا يوجد عملاء مسجلين', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));
                            }
                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                var doc = docs[index];
                                return Card(
                                  elevation: 0,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(backgroundColor: primaryNavy.withOpacity(0.05), child: Icon(Icons.person_outline, color: primaryNavy, size: 20)),
                                    title: Text(doc['name'], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: Text(doc['phone'] ?? 'بدون رقم', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600)),
                                    onTap: () {
                                      setState(() { _customerName = doc['name']; _customerId = doc.id; });
                                      parentSetState(() {});
                                      Navigator.pop(ctx);
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: primaryNavy.withOpacity(0.05),
                            foregroundColor: primaryNavy,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        onPressed: () => setLocalState(() => isAddingNew = true),
                        icon: const Icon(Icons.person_add),
                        label: const Text('إضافة عميل جديد للسيستم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),
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

  Widget _buildPaymentTypeBtn(String title, String currentSelection, Function(String) onSelect) {
    bool isSelected = title == currentSelection;
    return InkWell(
      onTap: () => onSelect(title),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: isSelected ? primaryNavy : Colors.transparent,
            border: Border.all(color: isSelected ? primaryNavy : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8)
        ),
        child: Center(
            child: Text(
                title,
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade700)
            )
        ),
      ),
    );
  }

  void _showCartAndCheckoutSheet() {
    ValueNotifier<String> paymentTypeNotifier = ValueNotifier<String>('كاش');
    TextEditingController partialAmountCtrl = TextEditingController();

    ValueNotifier<double> partialAmountNotifier = ValueNotifier<double>(0.0);
    partialAmountCtrl.addListener(() {
      partialAmountNotifier.value = double.tryParse(partialAmountCtrl.text) ?? 0.0;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
                  padding: const EdgeInsets.only(top: 16),
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('إتمام البيع', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                            // 👈 تم توحيد تصميم زر الإغلاق ليكون بإطار أسود وخلفية بيضاء
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.black87, width: 1.2)
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
                              ),
                            )
                          ],
                        ),
                      ),
                      const Divider(),

                      InkWell(
                        onTap: () => _showCustomersSheet(setSheetState),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              border: Border.all(color: Colors.blue.shade200),
                              borderRadius: BorderRadius.circular(12)
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(backgroundColor: Colors.blue.shade100, child: Icon(Icons.person, color: Colors.blue.shade700)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('العميل الحالي:', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                                    Text(_customerName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 14)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                child: const Text('تغيير العميل', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                        ),
                      ),
                      const Divider(),

                      Flexible(
                        child: _cartItems.isEmpty
                            ? const Center(child: Text('السلة فارغة', style: TextStyle(fontFamily: 'Cairo')))
                            : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _cartItems.length,
                          itemBuilder: (context, index) {
                            final item = _cartItems[index];
                            return ListTile(
                              title: Text(item['name'], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('${item['price']} ج.م', style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 11)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                    onPressed: () {
                                      setSheetState(() {
                                        setState(() {
                                          if (item['qty'] > 1) item['qty']--;
                                          else {
                                            _cartItems.removeAt(index);
                                            if (_cartItems.isEmpty) Navigator.pop(sheetContext);
                                          }
                                        });
                                      });
                                    },
                                  ),
                                  Text('${item['qty']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 20),
                                    onPressed: () {
                                      if (item['qty'] < item['stock']) setSheetState(() => setState(() => item['qty']++));
                                      else _showCustomSnackBar('المخزون لا يكفي', true);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                        child: ValueListenableBuilder<String>(
                            valueListenable: paymentTypeNotifier,
                            builder: (context, paymentType, child) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('الإجمالي:', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                                        Text('${_total.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: primaryNavy))
                                      ]
                                  ),
                                  const SizedBox(height: 10),

                                  Row(
                                    children: [
                                      Expanded(child: _buildPaymentTypeBtn('كاش', paymentType, (val) => paymentTypeNotifier.value = val)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _buildPaymentTypeBtn('آجل', paymentType, (val) => paymentTypeNotifier.value = val)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _buildPaymentTypeBtn('جزئي', paymentType, (val) => paymentTypeNotifier.value = val)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  if (paymentType == 'جزئي')
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: TextField(
                                        controller: partialAmountCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        decoration: InputDecoration(
                                          labelText: 'المبلغ المدفوع كاش الآن',
                                          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                                          prefixIcon: const Icon(Icons.attach_money),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: brandOrange, width: 2)),
                                        ),
                                      ),
                                    ),

                                  if (paymentType != 'كاش')
                                    ValueListenableBuilder<double>(
                                        valueListenable: partialAmountNotifier,
                                        builder: (context, partialAmount, child) {
                                          double paidAmount = paymentType == 'آجل' ? 0 : partialAmount;
                                          double remaining = _total - paidAmount;

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('المتبقي للآجل:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                                Text('${remaining.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                              ],
                                            ),
                                          );
                                        }
                                    ),

                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 45,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: brandOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      onPressed: () {
                                        double paidAmount = _total;
                                        if (paymentType == 'آجل') paidAmount = 0;
                                        if (paymentType == 'جزئي') paidAmount = partialAmountNotifier.value;

                                        if (paymentType == 'جزئي' && (paidAmount <= 0 || paidAmount >= _total)) {
                                          _showCustomSnackBar('المبلغ المدفوع غير صحيح', true);
                                          return;
                                        }
                                        _saveInvoice(sheetContext, paidAmount, paymentType);
                                      },
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: const Text('تأكيد وحفظ الفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                                    ),
                                  )
                                ],
                              );
                            }
                        ),
                      )
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
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
          ],
          title: const Text('المبيعات المباشرة (الشركة)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          elevation: 0,
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 8),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 10, mainAxisSpacing: 10),
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
                                        decoration: BoxDecoration(color: primaryNavy.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                                        child: imageUrl.isNotEmpty
                                            ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Icon(Icons.image_not_supported, size: 30, color: Colors.grey.shade400)))
                                            : Icon(Icons.inventory_2, size: 40, color: primaryNavy.withOpacity(0.3)),
                                      ),
                                      if (qtyInCart > 0)
                                        Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: CircleAvatar(radius: 12, backgroundColor: brandOrange, child: Text('$qtyInCart', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
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

        bottomNavigationBar: _cartItems.isEmpty ? null : Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              InkWell(
                onTap: _startNewInvoice,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 55,
                  width: 55,
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200)
                  ),
                  child: Icon(Icons.delete_sweep_rounded, color: Colors.red.shade700, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _showCartAndCheckoutSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 55,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        color: primaryNavy,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: primaryNavy.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: brandOrange, shape: BoxShape.circle), child: Text('${_cartItems.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            const SizedBox(width: 10),
                            const Text('مراجعة وإتمام', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        Text('${_total.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}