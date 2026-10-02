import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../invoices/logic/invoice_cubit.dart';
import '../../invoices/data/models/invoice_model.dart';
import '../../../../core/services/pdf_invoice_service.dart';

class AdminInvoicesScreen extends StatefulWidget {
  const AdminInvoicesScreen({super.key});

  @override
  State<AdminInvoicesScreen> createState() => _AdminInvoicesScreenState();
}

class _AdminInvoicesScreenState extends State<AdminInvoicesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<InvoiceCubit>().fetchAllInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text('سجل الفواتير والماليات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
            centerTitle: true,
            backgroundColor: const Color(0xFF0D1B2A),
            iconTheme: const IconThemeData(color: Colors.white),
            bottom: const TabBar(
              indicatorColor: Colors.amber,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white70,
              labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              tabs: [
                Tab(icon: Icon(Icons.outbound), text: 'فواتير المبيعات'),
                Tab(icon: Icon(Icons.inventory), text: 'فواتير المشتريات'),
              ],
            ),
          ),
          body: BlocBuilder<InvoiceCubit, InvoiceState>(
            builder: (context, state) {
              if (state is InvoiceListLoading) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF0D1B2A)));
              } else if (state is InvoiceListError) {
                return Center(child: Text(state.error, style: const TextStyle(color: Colors.red, fontFamily: 'Cairo')));
              } else if (state is InvoiceListLoaded) {
                return TabBarView(
                  children: [
                    _buildInvoiceList(state.salesInvoices, isSale: true),
                    _buildInvoiceList(state.purchaseInvoices, isSale: false),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceList(List<InvoiceModel> invoices, {required bool isSale}) {
    if (invoices.isEmpty) {
      return Center(
        child: Text(
          isSale ? 'لا توجد فواتير مبيعات بعد 📭' : 'لا توجد فواتير مشتريات بعد 📭',
          style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        final formattedDate = '${invoice.date.day}/${invoice.date.month}/${invoice.date.year}';

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. رأس الفاتورة (الرقم والحالة) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isSale ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          child: Icon(
                            isSale ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isSale ? Colors.green : Colors.red,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'بدون رقم تسلسلي',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: invoice.status == 'paid' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        invoice.status == 'paid' ? 'مدفوعة' : 'غير مدفوعة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                          color: invoice.status == 'paid' ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // --- 2. بيانات الفاتورة الأساسية ---
                Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('الطرف: ${invoice.partnerName.isNotEmpty ? invoice.partnerName : 'غير مسجل'}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('التاريخ: $formattedDate', style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo')),
                  ],
                ),
                const SizedBox(height: 12),

                // --- 3. 📦 تفاصيل المنتجات (الإضافة الجديدة) ---
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('تفاصيل المنتجات (${invoice.items.length}):', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Cairo')),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: invoice.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•', style: TextStyle(color: Colors.blueGrey, fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.productName,
                                style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // عرض الكمية والسعر معاً
                            Text(
                              '${item.quantity} x ${item.unitPrice} ج',
                              style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.black54, fontWeight: FontWeight.bold),
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // --- 4. الإجمالي ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي النهائي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                    Text(
                      '${invoice.totalAmount.toStringAsFixed(2)} ج.م',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isSale ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // --- 5. 📄 أزرار الطباعة والمشاركة ---
                const Text('الفاتورة الضريبية الرسمية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, fontFamily: 'Cairo')),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: () => _handlePrintOrShare(context, invoice, isDirectPrint: true),
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('طباعة مباشرة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: () => _handlePrintOrShare(context, invoice, isDirectPrint: false),
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('مشاركة واتساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0056D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handlePrintOrShare(BuildContext context, InvoiceModel invoice, {required bool isDirectPrint}) {
    if (isDirectPrint) {
      PdfInvoiceService.directPrintInvoice(invoice);
    } else {
      PdfInvoiceService.shareInvoicePdf(invoice);
    }

    final documentId = invoice.orderId.isNotEmpty ? invoice.orderId : invoice.id;

    FirebaseFirestore.instance.collection('orders').doc(documentId).update({
      'isInvoicePrinted': true,
      'printedAt': FieldValue.serverTimestamp(),
    }).catchError((e) {});
  }
}