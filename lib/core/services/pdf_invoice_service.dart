import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/invoices/data/models/invoice_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

class PdfInvoiceService {

  static Future<void> shareInvoicePdf(InvoiceModel invoice) async {
    final Uint8List pdfBytes = await _generatePdfBytes(invoice);

    String safeSupplier = invoice.partnerName.replaceAll(RegExp(r'[^\w\sà-üÀ-Ü-]'), '').trim();
    String safeInvNum = invoice.invoiceNumber.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    String dateStr = '${invoice.date.day}-${invoice.date.month}-${invoice.date.year}';

    String fileName = 'Invoice_${safeSupplier}_${safeInvNum}_$dateStr.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );
  }

  static Future<void> directPrintInvoice(InvoiceModel invoice) async {
    final Uint8List pdfBytes = await _generatePdfBytes(invoice);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  static Future<void> shareFilteredInvoicesReport(List<QueryDocumentSnapshot> docs, String filterTitle, double totalSum) async {
    final pdf = pw.Document();
    final ttfRegular = await PdfGoogleFonts.cairoRegular();
    final ttfBold = await PdfGoogleFonts.cairoBold();

    final ByteData logoBytes = await rootBundle.load('assets/images/RAMY_STORE_ERP_INVOICE_LOGO_1600x500.png');
    final Uint8List logoImage = logoBytes.buffer.asUint8List();

    pdf.addPage(
        pw.MultiPage(
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4,
              textDirection: pw.TextDirection.rtl,
              margin: const pw.EdgeInsets.all(30),
              theme: pw.ThemeData(defaultTextStyle: pw.TextStyle(font: ttfRegular, fontSize: 11)),
            ),
            header: (context) {
              return pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('تقرير مشتريات (كشف فواتير)', style: pw.TextStyle(font: ttfBold, fontSize: 16, color: PdfColors.blue900)),
                              pw.SizedBox(height: 6),
                              pw.Text('تاريخ التقرير: ${DateFormat('yyyy/MM/dd').format(DateTime.now())}', style: pw.TextStyle(font: ttfRegular, fontSize: 12)),
                              pw.SizedBox(height: 3),
                              pw.Text(filterTitle, style: pw.TextStyle(font: ttfBold, fontSize: 12, color: PdfColors.orange700)),
                            ]
                        ),
                        pw.Image(pw.MemoryImage(logoImage), width: 180),
                      ],
                    ),
                    pw.SizedBox(height: 15),
                    pw.Divider(color: PdfColors.blue900, thickness: 2),
                    pw.SizedBox(height: 15),
                  ]
              );
            },
            build: (context) {
              final tableData = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final invoiceDate = data['date'] != null ? DateFormat('dd/MM/yyyy').format((data['date'] as Timestamp).toDate()) : '';
                final totalAmt = double.tryParse(data['totalAmount'].toString()) ?? 0.0;
                return [
                  '${totalAmt.toStringAsFixed(2)} ج.م',
                  data['supplierName']?.toString() ?? '-',
                  data['invoiceNumber']?.toString() ?? '-',
                  invoiceDate,
                ];
              }).toList();

              return [
                pw.TableHelper.fromTextArray(
                  headers: ['الإجمالي', 'اسم المورد', 'رقم الفاتورة', 'التاريخ'],
                  data: tableData,
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(font: ttfBold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  cellStyle: pw.TextStyle(font: ttfRegular, fontSize: 10),
                  cellAlignment: pw.Alignment.center,
                  cellPadding: const pw.EdgeInsets.all(8),
                ),
                pw.SizedBox(height: 30),
                pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)), border: pw.Border.all(color: PdfColors.blue900)),
                    child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('عدد الفواتير: ${docs.length}', style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                          pw.Text('إجمالي التقرير: ${totalSum.toStringAsFixed(2)} ج.م', style: pw.TextStyle(font: ttfBold, fontSize: 14, color: PdfColors.blue900)),
                        ]
                    )
                )
              ];
            }
        )
    );

    final Uint8List bytes = await pdf.save();

    // 🌟 التعديل هنا: تسمية ملف كشف الحساب المجمع
    String safeTitle = filterTitle.replaceAll(':', '').replaceAll(' ', '_');
    String dateStr = '${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}';
    String fileName = '${safeTitle}_$dateStr.pdf';

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  static Future<Uint8List> _generatePdfBytes(InvoiceModel invoice) async {
    final pdf = pw.Document();
    final ttfRegular = await PdfGoogleFonts.cairoRegular();
    final ttfBold = await PdfGoogleFonts.cairoBold();
    final ByteData logoBytes = await rootBundle.load('assets/images/RAMY_STORE_ERP_INVOICE_LOGO_1600x500.png');
    final Uint8List logoImage = logoBytes.buffer.asUint8List();
    final ByteData watermarkBytes = await rootBundle.load('assets/images/RAMY_STORE_ERP_WATERMARK_2000x1200.png');
    final Uint8List watermarkImage = watermarkBytes.buffer.asUint8List();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(30),
          theme: pw.ThemeData(defaultTextStyle: pw.TextStyle(font: ttfRegular, fontSize: 11)),
          buildBackground: (context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Transform.translate(
                offset: const PdfPoint(0, -30),
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.35,
                    child: pw.Image(pw.MemoryImage(watermarkImage), width: 450, fit: pw.BoxFit.contain),
                  ),
                ),
              ),
            );
          },
        ),
        header: (context) => _buildHeader(invoice, ttfBold, ttfRegular, logoImage),
        build: (context) => [
          pw.SizedBox(height: 25),
          _buildInvoiceTable(invoice, ttfBold, ttfRegular),
        ],
        footer: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildWideFinancialSummary(invoice, ttfBold, ttfRegular),
              pw.SizedBox(height: 15),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text('شكراً لتعاملكم معنا\nتم إنشاء هذه الفاتورة آلياً بواسطة منظومة RAMY ERP', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttfRegular, fontSize: 10, color: PdfColors.grey600)),
              ),
            ]
        ),
      ),
    );
    return await pdf.save();
  }

  static pw.Widget _buildHeader(InvoiceModel invoice, pw.Font fontBold, pw.Font fontRegular, Uint8List logoImage) {
    String formattedDate = '${invoice.date.day}/${invoice.date.month}/${invoice.date.year}';
    String partyType = invoice.type == 'sale' ? '(عميل)' : '(مورد)';
    String invoiceTitle = invoice.type == 'sale' ? 'فاتورة مبيعات ضريبية' : 'فاتورة مشتريات ضريبية';

    bool isPaid = invoice.status == 'paid';

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(invoiceTitle, style: pw.TextStyle(font: fontBold, fontSize: 15, color: PdfColors.blue900)),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    children: [
                      pw.Text('رقم الفاتورة:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.SizedBox(width: 4),
                      pw.Text(invoice.invoiceNumber, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue800)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  _buildHeaderRow('التاريخ:', formattedDate, fontRegular, fontBold),
                  pw.SizedBox(height: 3),
                  _buildHeaderRow('الطرف:', '${invoice.partnerName} $partyType', fontRegular, fontBold),
                  pw.SizedBox(height: 3),
                  pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('الحالة:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                        pw.SizedBox(width: 4),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: isPaid ? PdfColors.green50 : PdfColors.red50,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            border: pw.Border.all(color: isPaid ? PdfColors.green700 : PdfColors.red700),
                          ),
                          child: pw.Text(
                            isPaid ? 'خالصة (مدفوعة)' : 'آجلة (غير مدفوعة)',
                            style: pw.TextStyle(font: fontBold, fontSize: 10, color: isPaid ? PdfColors.green800 : PdfColors.red900),
                          ),
                        ),
                      ]
                  )
                ],
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Directionality(
                textDirection: pw.TextDirection.ltr,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      height: 45,
                      width: 45,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'Store: RAMY SHOP ERP\nInv: ${invoice.invoiceNumber}\nTotal: ${invoice.totalAmount} EGP',
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Image(pw.MemoryImage(logoImage), width: 150),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.orange700, thickness: 2),
      ],
    );
  }

  static pw.Widget _buildHeaderRow(String title, String value, pw.Font fontTitle, pw.Font fontValue) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(title, style: pw.TextStyle(font: fontTitle, fontSize: 11)),
        pw.SizedBox(width: 5),
        pw.Text(value, style: pw.TextStyle(font: fontValue, fontSize: 11)),
      ],
    );
  }

  static pw.Widget _buildInvoiceTable(InvoiceModel invoice, pw.Font fontBold, pw.Font fontRegular) {
    return pw.TableHelper.fromTextArray(
      headers: ['الإجمالي', 'الكمية', 'سعر الوحدة', 'اسم المنتج'],
      data: invoice.items.map((item) {
        return [
          '${(item.unitPrice * item.quantity).toStringAsFixed(2)} ج.م',
          item.quantity.toString(),
          '${item.unitPrice.toStringAsFixed(2)} ج.م',
          item.productName,
        ];
      }).toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: pw.TextStyle(font: fontRegular),
      cellAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.all(8),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(3),
      },
    );
  }

  static pw.Widget _buildWideFinancialSummary(InvoiceModel invoice, pw.Font fontBold, pw.Font fontRegular) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.blue900, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('الإجمالي الفرعي:', '${invoice.subtotal.toStringAsFixed(2)} ج.م', fontRegular),
          pw.Container(height: 20, width: 1, color: PdfColors.grey400),
          _buildSummaryItem('خصم الكوبون:', invoice.discountAmount > 0 ? '- ${invoice.discountAmount.toStringAsFixed(2)} ج.م' : '0.00 ج.م', fontRegular, color: invoice.discountAmount > 0 ? PdfColors.red700 : PdfColors.black),
          pw.Container(height: 20, width: 1, color: PdfColors.grey400),
          _buildSummaryItem('الصافي النهائي:', '${invoice.totalAmount.toStringAsFixed(2)} ج.م', fontBold, isTotal: true, color: PdfColors.blue900),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String title, String value, pw.Font font, {bool isTotal = false, PdfColor color = PdfColors.black}) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(title, style: pw.TextStyle(font: font, fontSize: isTotal ? 14 : 11, color: PdfColors.grey700)),
        pw.SizedBox(width: 8),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: isTotal ? 15 : 11, color: color, fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }
}