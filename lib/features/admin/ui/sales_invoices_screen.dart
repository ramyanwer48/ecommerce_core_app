import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

class SalesInvoicesScreen extends StatelessWidget {
  const SalesInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF0D1B2A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('سجل المبيعات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: primaryNavy,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: StreamBuilder<QuerySnapshot>(
          // 👈 بيقرأ كل حركات البيع من كل العملاء
          stream: FirebaseFirestore.instance.collection('ledger_entries')
              .where('type', isEqualTo: 'sale')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('لا توجد فواتير مبيعات حتى الآن.', style: TextStyle(fontFamily: 'Cairo')));
            }

            final invoices = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                var data = invoices[index].data() as Map<String, dynamic>;
                String customerName = data['partnerName'] ?? 'عميل غير معروف';
                double amount = (data['amount'] ?? 0).toDouble();
                String note = data['note'] ?? '';
                Timestamp? date = data['date'] as Timestamp?;

                String dateStr = date != null ? DateFormat('yyyy-MM-dd hh:mm a').format(date.toDate()) : '';

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.orange.shade100, child: const Icon(Icons.receipt_long, color: Colors.orange)),
                    title: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade700)),
                        Text(dateStr, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    trailing: Text('${amount.toStringAsFixed(2)} ج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}