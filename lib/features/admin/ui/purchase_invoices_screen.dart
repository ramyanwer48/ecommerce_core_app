import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../invoices/logic/invoice_cubit.dart';
import '../../invoices/data/models/invoice_model.dart';
import '../../../../core/services/pdf_invoice_service.dart';

class PurchaseInvoicesScreen extends StatefulWidget {
  const PurchaseInvoicesScreen({super.key});

  @override
  State<PurchaseInvoicesScreen> createState() => _PurchaseInvoicesScreenState();
}

class _PurchaseInvoicesScreenState extends State<PurchaseInvoicesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<InvoiceCubit>().fetchAllInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('سجل فواتير المشتريات (الموردين)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo', fontSize: 18)),
          centerTitle: true,
          backgroundColor: const Color(0xFF0D1B2A),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Directionality(textDirection: TextDirection.ltr, child: Icon(Icons.arrow_back)),
            onPressed: () => context.pop(),
          ),
        ),
        body: BlocBuilder<InvoiceCubit, InvoiceState>(
          builder: (context, state) {
            if (state is InvoiceListLoading) {
              return const Center(child: CircularProgressIndicator(color: Colors.indigo));
            } else if (state is InvoiceListError) {
              return Center(child: Text(state.error, style: const TextStyle(color: Colors.red, fontFamily: 'Cairo')));
            } else if (state is InvoiceListLoaded) {
              // 💡 هنا بنمرر قائمة فواتير المشتريات فقط
              return _buildInvoiceList(state.purchaseInvoices);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildInvoiceList(List<InvoiceModel> invoices) {
    if (invoices.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد فواتير مشتريات من الموردين حتى الآن 📭',
          style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.indigo.withOpacity(0.1),
                          child: const Icon(Icons.arrow_downward, color: Colors.indigo, size: 18),
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
                      decoration: BoxDecoration(color: invoice.status == 'paid' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        invoice.status == 'paid' ? 'تم الدفع للمورد' : 'آجل / غير مدفوع',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: invoice.status == 'paid' ? Colors.green : Colors.orange),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.store, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('المورد: ${invoice.partnerName.isNotEmpty ? invoice.partnerName : 'غير مسجل'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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
                Row(
                  children: [
                    const Icon(Icons.inventory, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('تفاصيل البضاعة الواردة (${invoice.items.length}):', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Cairo')),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    children: invoice.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•', style: TextStyle(color: Colors.blueGrey, fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text('${item.quantity} x ${item.unitPrice} ج', style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.black54, fontWeight: FontWeight.bold), textDirection: TextDirection.ltr),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('تكلفة الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                    Text('${invoice.totalAmount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: () => _handlePrintOrShare(context, invoice, isDirectPrint: true),
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('طباعة سند استلام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo')),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
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
  }
}