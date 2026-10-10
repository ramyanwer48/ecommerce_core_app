import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../../core/services/pdf_invoice_service.dart';
import '../../invoices/data/models/invoice_model.dart';

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

  DateTimeRange? _selectedDateRange;
  String _filterSource = 'All';
  String _filterType = 'All';

  String _formatMoney(double amount) {
    return amount.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
  }

  Future<void> _openInvoicePdf(String ledgerDocId, String displayNote) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator(color: brandOrange)));
    try {
      String orderId = ledgerDocId.replaceFirst('sale_', '').replaceFirst('order_', '').trim();
      DocumentSnapshot orderDoc = await _firestore.collection('orders').doc(orderId).get();

      if (orderDoc.exists) {
        var data = orderDoc.data() as Map<String, dynamic>;
        List<dynamic> rawItems = data['items'] ?? [];
        List<InvoiceItemModel> items = rawItems.map((i) => InvoiceItemModel(
          productId: i['productId'] ?? i['id'] ?? '',
          productName: i['name'] ?? i['productName'] ?? 'منتج',
          unitPrice: double.tryParse((i['price'] ?? i['unitPrice'] ?? 0).toString()) ?? 0.0,
          quantity: int.tryParse((i['quantity'] ?? 1).toString()) ?? 1,
        )).toList();

        Timestamp? dateTs = data['createdAt'] ?? data['orderDate'] ?? data['date'];
        String displayInvoiceNum = data['orderNumber']?.toString() ?? 'INV-${orderId.substring(0, 5)}';

        InvoiceModel invoice = InvoiceModel(
          id: orderId,
          invoiceNumber: displayInvoiceNum,
          partnerId: widget.customerId,
          partnerName: widget.customerName,
          type: 'sale',
          items: items,
          subtotal: double.tryParse((data['subtotal'] ?? 0).toString()) ?? 0.0,
          discountAmount: double.tryParse((data['discountAmount'] ?? 0).toString()) ?? 0.0,
          totalAmount: double.tryParse((data['totalPrice'] ?? data['totalAmount'] ?? 0).toString()) ?? 0.0,
          date: dateTs != null ? dateTs.toDate() : DateTime.now(),
          status: 'paid',
        );

        if (mounted) {
          Navigator.pop(context);
          PdfInvoiceService.directPrintInvoice(invoice);
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عفواً، الفاتورة غير متوفرة', style: TextStyle(fontFamily: 'Cairo'))));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في جلب الفاتورة: $e', style: const TextStyle(fontFamily: 'Cairo'))));
      }
    }
  }

  void _showAdvancedFilterSheet() {
    String tempFilterSource = _filterSource;
    String tempFilterType = _filterType;
    DateTimeRange? tempDateRange = _selectedDateRange;

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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('تصفية الحركات', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black87, width: 1.2)),
                                child: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
                              ),
                            )
                          ],
                        ),
                        const Divider(height: 20),

                        const Text('الفترة الزمنية:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final DateTimeRange? picked = await showDateRangePicker(
                              context: context,
                              initialDateRange: tempDateRange,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              builder: (context, child) => Theme(
                                data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: brandOrange, onPrimary: Colors.white, onSurface: primaryNavy)),
                                child: Directionality(textDirection: TextDirection.rtl, child: child!),
                              ),
                            );
                            if (picked != null) setSheetState(() => tempDateRange = picked);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: tempDateRange != null ? brandOrange : Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Icon(Icons.date_range, color: tempDateRange != null ? brandOrange : Colors.grey.shade600),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tempDateRange == null
                                        ? 'تحديد فترة (من - إلى)'
                                        : '${DateFormat('yyyy-MM-dd').format(tempDateRange!.start)} إلى ${DateFormat('yyyy-MM-dd').format(tempDateRange!.end)}',
                                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: tempDateRange == null ? Colors.grey.shade700 : primaryNavy),
                                  ),
                                ),
                                if (tempDateRange != null)
                                  InkWell(onTap: () => setSheetState(() => tempDateRange = null), child: const Icon(Icons.close, color: Colors.red, size: 20))
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text('مصدر الحركة (المكان):', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _buildFilterChip('الكل', 'All', tempFilterSource, (val) => setSheetState(() => tempFilterSource = val), Icons.all_inclusive),
                            _buildFilterChip('الشركة', 'POS', tempFilterSource, (val) => setSheetState(() => tempFilterSource = val), Icons.storefront),
                            _buildFilterChip('أونلاين', 'Online', tempFilterSource, (val) => setSheetState(() => tempFilterSource = val), Icons.language),
                            _buildFilterChip('تحويل/محفظة', 'Transfer', tempFilterSource, (val) => setSheetState(() => tempFilterSource = val), Icons.phone_iphone),
                          ],
                        ),
                        const SizedBox(height: 20),

                        const Text('نوع الحركة المحاسبية:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _buildFilterChip('الكل', 'All', tempFilterType, (val) => setSheetState(() => tempFilterType = val), Icons.list),
                            _buildFilterChip('المبيعات', 'Sale', tempFilterType, (val) => setSheetState(() => tempFilterType = val), Icons.shopping_bag_outlined),
                            _buildFilterChip('السدادات', 'Receipt', tempFilterType, (val) => setSheetState(() => tempFilterType = val), Icons.arrow_downward),
                          ],
                        ),
                        const SizedBox(height: 30),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: brandOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () {
                              setState(() {
                                _filterSource = tempFilterSource;
                                _filterType = tempFilterType;
                                _selectedDateRange = tempDateRange;
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text('تطبيق الفلتر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            }
        )
    );
  }

  Widget _buildFilterChip(String label, String value, String groupValue, Function(String) onSelect, IconData icon) {
    bool isSelected = groupValue == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : primaryNavy),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : primaryNavy)),
        ],
      ),
      selected: isSelected,
      onSelected: (bool selected) { if (selected) onSelect(value); },
      selectedColor: primaryNavy,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? primaryNavy : Colors.grey.shade300)),
      showCheckmark: false,
    );
  }

  void _showReceiptSheet(BuildContext mainContext, {DocumentSnapshot? existingDoc}) {
    final bool isEditing = existingDoc != null;
    final Map<String, dynamic>? data = isEditing ? existingDoc.data() as Map<String, dynamic>? : null;

    final TextEditingController amountController = TextEditingController(text: isEditing ? (data?['amount'] ?? '').toString() : '');
    final TextEditingController noteController = TextEditingController(text: isEditing ? (data?['note'] ?? '') : '');
    final TextEditingController transferNumController = TextEditingController();

    String paymentMethod = 'نقدي (الشركة)';
    if (isEditing) {
      if (noteController.text.contains('تحويل') || noteController.text.contains('محفظة')) paymentMethod = 'تحويل مالي';
    }

    File? selectedImage;
    String? existingImageUrl = isEditing ? (data?['imageUrl'] as String?) : null;
    bool isSaving = false;

    showModalBottomSheet(
      context: mainContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
          builder: (modalContext, setSheetState) {
            bool isTransfer = paymentMethod == 'تحويل مالي';

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom, left: 20, right: 20, top: 20),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 40),
                          Expanded(
                            child: Text(
                                isEditing ? 'تعديل السداد' : 'تسجيل سداد جديد',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black87, width: 1.2)),
                              child: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
                            ),
                          )
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),

                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: primaryNavy),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                            labelText: 'المبلغ المحصل',
                            labelStyle: TextStyle(color: brandOrange, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: brandOrange, width: 2)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            suffixText: 'ج.م   ',
                            suffixStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: brandOrange)
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('طريقة السداد:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setSheetState(() => paymentMethod = 'نقدي (الشركة)'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                    color: !isTransfer ? Colors.teal.shade700 : Colors.transparent,
                                    border: Border.all(color: !isTransfer ? Colors.teal.shade700 : Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8)
                                ),
                                child: Center(child: Text('نقدي (الشركة)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: !isTransfer ? Colors.white : Colors.grey.shade700))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => setSheetState(() => paymentMethod = 'تحويل مالي'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                    color: isTransfer ? brandOrange : Colors.transparent,
                                    border: Border.all(color: isTransfer ? brandOrange : Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8)
                                ),
                                child: Center(child: Text('تحويل/محفظة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isTransfer ? Colors.white : Colors.grey.shade700))),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (isTransfer) ...[
                        TextField(
                          controller: transferNumController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                              labelText: 'رقم المحفظة المحول منها (إلزامي)',
                              prefixIcon: const Icon(Icons.phone_iphone),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.contacts, color: Colors.blue),
                                onPressed: () async {
                                  try {
                                    if (await FlutterContacts.requestPermission(readonly: true)) {
                                      Contact? contact = await FlutterContacts.openExternalPick();
                                      if (contact != null && contact.phones.isNotEmpty) {
                                        String cleanPhone = contact.phones.first.number.replaceAll(RegExp(r'\s+'), '');
                                        setSheetState(() => transferNumController.text = cleanPhone);
                                      }
                                    } else {
                                      ScaffoldMessenger.of(mainContext).showSnackBar(const SnackBar(content: Text('تم رفض الصلاحية', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                                    }
                                  } catch (e) {
                                    debugPrint("Contacts Error: $e");
                                  }
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
                          ),
                        ),
                        const SizedBox(height: 12),

                        selectedImage != null
                            ? Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(selectedImage!, height: 120, width: double.infinity, fit: BoxFit.cover),
                            ),
                            Container(
                              margin: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                onPressed: () => setSheetState(() => selectedImage = null),
                              ),
                            ),
                          ],
                        )
                            : (existingImageUrl != null
                            ? Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(existingImageUrl!, height: 120, width: double.infinity, fit: BoxFit.cover),
                            ),
                            Container(
                              margin: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                onPressed: () => setSheetState(() => existingImageUrl = null),
                              ),
                            ),
                          ],
                        )
                            : InkWell(
                          onTap: () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                            if (pickedFile != null) setSheetState(() => selectedImage = File(pickedFile.path));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                                borderRadius: BorderRadius.circular(10)
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, color: primaryNavy),
                                const SizedBox(width: 8),
                                Text('إرفاق صورة الإيصال (اختياري)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: primaryNavy)),
                              ],
                            ),
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],

                      TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                            labelText: 'ملاحظات إضافية (اختياري)',
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
                        ),
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: brandOrange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        onPressed: isSaving ? null : () async {
                          String amountText = amountController.text.trim();

                          amountText = amountText
                              .replaceAll('٠', '0').replaceAll('١', '1').replaceAll('٢', '2')
                              .replaceAll('٣', '3').replaceAll('٤', '4').replaceAll('٥', '5')
                              .replaceAll('٦', '6').replaceAll('٧', '7').replaceAll('٨', '8')
                              .replaceAll('٩', '9');

                          if (amountText.isEmpty) {
                            ScaffoldMessenger.of(mainContext).showSnackBar(const SnackBar(content: Text('الرجاء إدخال المبلغ أولاً', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                            return;
                          }

                          double newAmount = double.tryParse(amountText) ?? 0;
                          if (newAmount <= 0) {
                            ScaffoldMessenger.of(mainContext).showSnackBar(const SnackBar(content: Text('المبلغ المدخل غير صحيح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                            return;
                          }

                          if (isTransfer && transferNumController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(mainContext).showSnackBar(const SnackBar(content: Text('يرجى إدخال رقم المحفظة المحول منها', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                            return;
                          }

                          setSheetState(() => isSaving = true);

                          String finalNote = noteController.text.trim();
                          if (isTransfer) {
                            finalNote = 'سداد تحويل من: ${transferNumController.text.trim()}' + (finalNote.isNotEmpty ? ' - $finalNote' : '');
                          } else {
                            finalNote = 'سداد نقدي (الشركة)' + (finalNote.isNotEmpty ? ' - $finalNote' : '');
                          }

                          String? finalImageUrl = existingImageUrl;

                          if (selectedImage != null) {
                            try {
                              String fileName = 'receipts/${DateTime.now().millisecondsSinceEpoch}.jpg';
                              TaskSnapshot snap = await FirebaseStorage.instance.ref(fileName).putFile(selectedImage!).timeout(const Duration(seconds: 15));
                              finalImageUrl = await snap.ref.getDownloadURL();
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              ScaffoldMessenger.of(mainContext).showSnackBar(const SnackBar(content: Text('مشكلة في رفع الصورة! تأكد من إعدادات الـ Storage في الفايربيز.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red, duration: Duration(seconds: 4)));
                              return;
                            }
                          }

                          try {
                            WriteBatch batch = _firestore.batch();
                            DocumentReference customerRef = _firestore.collection('customers').doc(widget.customerId);

                            if (isEditing) {
                              double oldAmount = double.tryParse((data?['amount'] ?? 0).toString()) ?? 0.0;
                              double difference = newAmount - oldAmount;
                              DocumentReference ledgerRef = existingDoc.reference;

                              Map<String, dynamic> updateData = {'amount': newAmount, 'note': finalNote, 'updatedAt': FieldValue.serverTimestamp()};
                              updateData['imageUrl'] = finalImageUrl;

                              batch.update(ledgerRef, updateData);
                              if (difference != 0) batch.update(customerRef, {'balance': FieldValue.increment(-difference)});
                            } else {
                              DocumentReference ledgerRef = _firestore.collection('ledger_entries').doc();
                              Map<String, dynamic> insertData = {'partnerId': widget.customerId, 'partnerName': widget.customerName, 'type': 'receipt', 'amount': newAmount, 'date': FieldValue.serverTimestamp(), 'note': finalNote};
                              if (finalImageUrl != null) insertData['imageUrl'] = finalImageUrl;

                              batch.set(ledgerRef, insertData);
                              batch.update(customerRef, {'balance': FieldValue.increment(-newAmount)});
                            }

                            await batch.commit();

                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(mainContext).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح وتحديث الحساب', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                            }

                          } catch (e) {
                            setSheetState(() => isSaving = false);
                            ScaffoldMessenger.of(mainContext).showSnackBar(SnackBar(content: Text('خطأ في حفظ البيانات: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                          }
                        },
                        child: isSaving
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(isEditing ? 'حفظ التعديلات' : 'تأكيد السداد', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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

  Future<void> _deleteReceiptEntry(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;
    double amount = double.tryParse((data['amount'] ?? 0).toString()) ?? 0.0;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف السداد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذا السداد؟ سيتم إعادة المبلغ لمديونية العميل.', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.red))),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        WriteBatch batch = _firestore.batch();
        batch.delete(doc.reference);
        DocumentReference customerRef = _firestore.collection('customers').doc(widget.customerId);
        batch.update(customerRef, {'balance': FieldValue.increment(amount)});
        await batch.commit();
      } catch (e) {
        debugPrint(e.toString());
      }
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime dt = timestamp.toDate();
    return '${dt.day}/${dt.month}/${dt.year} | ${DateFormat('hh:mm a').format(dt)}';
  }

  void _showReceiptImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(imageUrl, fit: BoxFit.contain, loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(child: CircularProgressIndicator(color: brandOrange));
              }),
            ),
            IconButton(icon: const Icon(Icons.cancel, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context))
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFiltered = _selectedDateRange != null || _filterSource != 'All' || _filterType != 'All';

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
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('كشف حساب (${widget.customerName})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          ),
          centerTitle: true,
          backgroundColor: primaryNavy,
          elevation: 0,
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      isFiltered ? 'فلاتر نشطة' : 'عرض كل الحركات',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isFiltered ? brandOrange : Colors.grey.shade800, fontSize: 14)
                  ),
                  Row(
                    children: [
                      if (isFiltered) ...[
                        InkWell(
                          onTap: () {
                            setState(() {
                              _filterSource = 'All';
                              _filterType = 'All';
                              _selectedDateRange = null;
                            });
                          },
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
                        onTap: _showAdvancedFilterSheet,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            color: isFiltered ? brandOrange : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: brandOrange),
                          ),
                          child: Icon(Icons.tune_rounded, color: isFiltered ? Colors.white : brandOrange, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('ledger_entries').where('partnerId', isEqualTo: widget.customerId).snapshots(),
              builder: (context, snapshot) {
                double totalSales = 0;
                double totalReceipts = 0;
                double currentBal = widget.currentBalance;

                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    var d = doc.data() as Map<String, dynamic>;
                    String type = d['type'] ?? '';
                    String note = d['note'] ?? '';
                    Timestamp? ts = d['date'] ?? d['createdAt'];

                    bool isOnline = note.contains('أونلاين') || note.contains('متجر');
                    bool isTransfer = note.contains('تحويل') || note.contains('محفظة');
                    bool isPos = !isOnline && !isTransfer;

                    bool inRange = true;
                    if (_selectedDateRange != null && ts != null) {
                      DateTime dt = ts.toDate();
                      DateTime justDt = DateTime(dt.year, dt.month, dt.day);
                      DateTime start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
                      DateTime end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
                      if (justDt.isBefore(start) || justDt.isAfter(end)) inRange = false;
                    }
                    if (_filterType == 'Sale' && type != 'sale') inRange = false;
                    if (_filterType == 'Receipt' && type != 'receipt') inRange = false;
                    if (_filterSource == 'Online' && !isOnline) inRange = false;
                    if (_filterSource == 'POS' && !isPos) inRange = false;
                    if (_filterSource == 'Transfer' && !isTransfer) inRange = false;

                    if (inRange) {
                      double amt = double.tryParse((d['amount'] ?? 0).toString()) ?? 0;
                      if (type == 'sale' || type == 'invoice') totalSales += amt;
                      if (type == 'receipt') totalReceipts += amt;
                    }
                  }
                }

                return Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: brandOrange.withOpacity(0.5), width: 2),
                    boxShadow: [BoxShadow(color: brandOrange.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isFiltered ? 'مبيعات (حسب الفلتر)' : 'إجمالي مسحوباته', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isFiltered ? brandOrange : Colors.grey)),
                              Text('${_formatMoney(totalSales)} ج', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(isFiltered ? 'مدفوعات (حسب الفلتر)' : 'إجمالي مدفوعاته', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isFiltered ? brandOrange : Colors.grey)),
                              Text('${_formatMoney(totalReceipts)} ج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade700)),
                            ],
                          ),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(thickness: 1)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الرصيد المستحق الكلي:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: currentBal > 0 ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              '${_formatMoney(currentBal)} ج.م',
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 20, color: currentBal > 0 ? Colors.red.shade700 : Colors.green.shade700),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('ledger_entries').where('partnerId', isEqualTo: widget.customerId).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: primaryNavy));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد حركات مسجلة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));

                  var docs = snapshot.data!.docs.toList();

                  docs = docs.where((doc) {
                    var d = doc.data() as Map<String, dynamic>;
                    String type = d['type'] ?? '';
                    String note = d['note'] ?? '';
                    Timestamp? ts = d['date'] ?? d['createdAt'];

                    bool isOnline = note.contains('أونلاين') || note.contains('متجر');
                    bool isTransfer = note.contains('تحويل') || note.contains('محفظة');
                    bool isPos = !isOnline && !isTransfer;

                    if (_selectedDateRange != null && ts != null) {
                      DateTime dt = ts.toDate();
                      DateTime justDt = DateTime(dt.year, dt.month, dt.day);
                      DateTime start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
                      DateTime end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
                      if (justDt.isBefore(start) || justDt.isAfter(end)) return false;
                    }

                    if (_filterType == 'Sale' && type != 'sale') return false;
                    if (_filterType == 'Receipt' && type != 'receipt') return false;
                    if (_filterSource == 'Online' && !isOnline) return false;
                    if (_filterSource == 'POS' && !isPos) return false;
                    if (_filterSource == 'Transfer' && !isTransfer) return false;

                    return true;
                  }).toList();

                  if (docs.isEmpty) return const Center(child: Text('لا توجد حركات تطابق الفلتر', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));

                  docs.sort((a, b) {
                    var dataA = a.data() as Map<String, dynamic>;
                    var dataB = b.data() as Map<String, dynamic>;
                    Timestamp? timeA = dataA['date'] ?? dataA['createdAt'];
                    Timestamp? timeB = dataB['date'] ?? dataB['createdAt'];
                    if (timeA == null && timeB == null) return 0;
                    if (timeA == null) return 1;
                    if (timeB == null) return -1;
                    return timeB.compareTo(timeA);
                  });

                  return ListView.builder(
                    itemCount: docs.length,
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
                    itemBuilder: (context, index) {
                      var doc = docs[index];
                      var data = doc.data() as Map<String, dynamic>;

                      String type = data['type'] ?? 'unknown';
                      double amount = double.tryParse((data['amount'] ?? 0).toString()) ?? 0.0;
                      String note = data['note'] ?? '';
                      String? imageUrl = data['imageUrl'];
                      Timestamp? date = data['date'] ?? data['createdAt'];

                      bool isReceipt = type == 'receipt';
                      bool isSale = type == 'sale' || type == 'invoice';
                      if (!isReceipt && !isSale) return const SizedBox.shrink();

                      bool isOnline = note.contains('أونلاين') || note.contains('متجر');
                      bool isTransfer = note.contains('تحويل') || note.contains('محفظة');
                      bool isAutomatedSystemEntry = isOnline || note.contains('أوتوماتيكي') || note.contains('مباشرة');

                      Color badgeColor = isOnline ? Colors.blue.shade700 : (isTransfer ? brandOrange : Colors.teal.shade700);
                      Color badgeBg = isOnline ? Colors.blue.shade50 : (isTransfer ? brandOrange.withOpacity(0.1) : Colors.teal.shade50);
                      IconData sourceIcon = isOnline ? Icons.language : (isTransfer ? Icons.phone_iphone : Icons.storefront);
                      String sourceText = isOnline ? 'أونلاين' : (isTransfer ? 'تحويل مالي' : 'نقدي (الشركة)');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isReceipt ? Colors.green.shade100 : Colors.red.shade100, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: isReceipt ? Colors.green.shade50 : Colors.red.shade50, shape: BoxShape.circle),
                              child: Icon(isReceipt ? Icons.arrow_downward : Icons.shopping_bag_outlined, size: 18, color: isReceipt ? Colors.green.shade700 : Colors.red.shade700),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(isReceipt ? 'سداد' : 'فاتورة مبيعات', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                                        child: Row(
                                          children: [
                                            Icon(sourceIcon, size: 10, color: badgeColor),
                                            const SizedBox(width: 2),
                                            Text(sourceText, style: TextStyle(fontFamily: 'Cairo', fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(_formatDate(date), style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),

                                  if (imageUrl != null) ...[
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => _showReceiptImage(imageUrl),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imageUrl,
                                          height: 50,
                                          width: 80,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              height: 50, width: 80,
                                              color: Colors.grey.shade200,
                                              child: const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${_formatMoney(amount)} ج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: isReceipt ? Colors.green.shade700 : Colors.red.shade700)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (isSale)
                                      InkWell(
                                        onTap: () => _openInvoicePdf(doc.id, note),
                                        child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.print_outlined, size: 18, color: Colors.blue)),
                                      ),
                                    if (isReceipt && !isAutomatedSystemEntry) ...[
                                      InkWell(
                                        onTap: () => _showReceiptSheet(context, existingDoc: doc),
                                        child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.edit_outlined, size: 18, color: Colors.orange)),
                                      ),
                                      InkWell(
                                        onTap: () => _deleteReceiptEntry(doc),
                                        child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.delete_outline, size: 18, color: Colors.red)),
                                      ),
                                    ]
                                  ],
                                )
                              ],
                            )
                          ],
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
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('تسجيل سداد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }
}