import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../invoices/logic/invoice_cubit.dart';
import '../../invoices/data/models/invoice_model.dart';

class AdminInvoicesScreen extends StatefulWidget {
  const AdminInvoicesScreen({super.key});

  @override
  State<AdminInvoicesScreen> createState() => _AdminInvoicesScreenState();
}

class _AdminInvoicesScreenState extends State<AdminInvoicesScreen> {
  @override
  void initState() {
    super.initState();
    // جلب الفواتير بمجرد فتح الشاشة
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
            title: const Text('سجل الفواتير', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            centerTitle: true,
            backgroundColor: const Color(0xFF000826),
            iconTheme: const IconThemeData(color: Colors.white),
            bottom: const TabBar(
              indicatorColor: Colors.amber,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(icon: Icon(Icons.outbound), text: 'فواتير المبيعات'),
                Tab(icon: Icon(Icons.inventory), text: 'فواتير المشتريات'),
              ],
            ),
          ),
          body: BlocBuilder<InvoiceCubit, InvoiceState>(
            builder: (context, state) {
              if (state is InvoiceListLoading) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF000826)));
              } else if (state is InvoiceListError) {
                return Center(child: Text(state.error, style: const TextStyle(color: Colors.red)));
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
          style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
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
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: isSale ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              child: Icon(
                isSale ? Icons.arrow_upward : Icons.arrow_downward,
                color: isSale ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'بدون رقم تسلسلي',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الطرف: ${invoice.partnerName.isNotEmpty ? invoice.partnerName : 'غير مسجل'}', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('التاريخ: $formattedDate', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${invoice.totalAmount.toStringAsFixed(2)} ج.م',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isSale ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: invoice.status == 'paid' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    invoice.status == 'paid' ? 'مدفوعة' : 'غير مدفوعة',
                    style: TextStyle(
                      fontSize: 11,
                      color: invoice.status == 'paid' ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}