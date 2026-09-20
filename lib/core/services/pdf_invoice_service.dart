import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/invoices/data/models/invoice_model.dart';

class PdfInvoiceService {

  // 1️⃣ زر التصدير والمشاركة (واتساب وحفظ الملف)
  static Future<void> shareInvoicePdf(InvoiceModel invoice) async {
    final Uint8List pdfBytes = await _generatePdfBytes(invoice);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  // 2️⃣ زر الطباعة المباشرة (يبحث عن الطابعات المتصلة ويطبع فوراً)
  static Future<void> directPrintInvoice(InvoiceModel invoice) async {
    final Uint8List pdfBytes = await _generatePdfBytes(invoice);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  // الدالة المركزية لتوليد ملف الـ PDF
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

          // العلامة المائية في منتصف منطقة الجدول بوضوح 35%
          buildBackground: (context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Transform.translate(
                offset: const PdfPoint(0, -30),
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.35,
                    child: pw.Image(
                        pw.MemoryImage(watermarkImage),
                        width: 450,
                        fit: pw.BoxFit.contain
                    ),
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

        // الإجماليات في أسفل الصفحة تماماً
        footer: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildWideFinancialSummary(invoice, ttfBold, ttfRegular),
              pw.SizedBox(height: 15),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text('شكراً لتعاملكم معنا - تم إنشاء هذه الفاتورة آلياً بواسطة منظومة RAMY ERP',
                    style: pw.TextStyle(font: ttfRegular, fontSize: 10, color: PdfColors.grey600)),
              ),
            ]
        ),
      ),
    );

    return await pdf.save();
  }

  // الهيدر: اليمين (التفاصيل) | الشمال (الـ QR على أقصى الشمال الفعلي، وجنبه اللوجو الأكبر حجماً)
  static pw.Widget _buildHeader(InvoiceModel invoice, pw.Font fontBold, pw.Font fontRegular, Uint8List logoImage) {
    String formattedDate = '${invoice.date.day}/${invoice.date.month}/${invoice.date.year}';
    String partyType = invoice.type == 'sale' ? '(عميل)' : '(مورد)';
    String invoiceTitle = invoice.type == 'sale' ? 'فاتورة مبيعات ضريبية' : 'فاتورة مشتريات ضريبية';

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // أقصى اليمين: تفاصيل الفاتورة
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(invoiceTitle, style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900)),
                pw.SizedBox(height: 6),
                _buildHeaderRow('رقم الفاتورة:', invoice.invoiceNumber, fontBold, fontBold),
                pw.SizedBox(height: 3),
                _buildHeaderRow('التاريخ:', formattedDate, fontRegular, fontBold),
                pw.SizedBox(height: 3),
                _buildHeaderRow('الطرف:', '${invoice.partnerName} $partyType', fontRegular, fontBold),
                pw.SizedBox(height: 3),
                pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('الحالة:', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                      pw.SizedBox(width: 5),
                      pw.Text(invoice.status == 'paid' ? 'خالصة (مدفوعة)' : 'آجلة',
                          style: pw.TextStyle(font: fontBold, fontSize: 11, color: invoice.status == 'paid' ? PdfColors.green700 : PdfColors.red700)),
                    ]
                )
              ],
            ),

            // 👈 تثبيت اتجاه هذا الجزء ليكون LTR صريح: الـ QR على أقصى الشمال، واللوجو جنبه على اليمين منه
            pw.Directionality(
              textDirection: pw.TextDirection.ltr,
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    height: 65,
                    width: 65,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'Store: RAMY SHOP ERP\nInv: ${invoice.invoiceNumber}\nTotal: ${invoice.totalAmount} EGP',
                      color: PdfColors.blue900,
                    ),
                  ), // QR Code على أقصى الشمال تماماً
                  pw.SizedBox(width: 15),
                  pw.Image(pw.MemoryImage(logoImage), width: 220), // اللوجو الكبير جنبه
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
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

  // جدول المنتجات (البيانات في المنتصف)
  static pw.Widget _buildInvoiceTable(InvoiceModel invoice, pw.Font fontBold, pw.Font fontRegular) {
    return pw.TableHelper.fromTextArray(
      headers: ['الإجمالي', 'الكمية', 'سعر الوحدة', 'اسم المنتج'],
      data: invoice.items.map((item) {
        return [
          '${item.totalItemPrice.toStringAsFixed(2)} ج.م',
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

  // المستطيل العرضي المالي في الأسفل تماماً
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