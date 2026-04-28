import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice.dart';
import '../models/job.dart';
import '../models/app_settings.dart';
import '../utils/formatters.dart';
import 'logo_service.dart';

Future<void> printInvoice(Invoice inv, AppSettings settings) async {
  final logoBytes = await loadLogo();
  final pdf = _buildPdf(inv, settings, logoBytes);
  await Printing.layoutPdf(onLayout: (_) async => pdf.save());
}

Future<void> downloadInvoice(Invoice inv, AppSettings settings) async {
  final logoBytes = await loadLogo();
  final pdf = _buildPdf(inv, settings, logoBytes);
  final bytes = await pdf.save();
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'facture-${inv.number}.pdf',
  );
}

pw.Document _buildPdf(Invoice inv, AppSettings settings, Uint8List? logoBytes) {
  final pdf = pw.Document();
  final totals = _totals(inv);
  final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(inv, settings, logo),
          pw.SizedBox(height: 16),
          _linesTable(inv),
          pw.SizedBox(height: 12),
          _totalsPanel(inv, totals),
          if (inv.notes.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Notes : ${inv.notes}',
                style: const pw.TextStyle(fontSize: 9)),
          ],
          pw.Spacer(),
          _footer(settings),
        ],
      ),
    ),
  );
  return pdf;
}

pw.Widget _header(Invoice inv, AppSettings s, pw.ImageProvider? logo) =>
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: logo then company info below it
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[
                pw.Container(
                  height: 60,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Image(
                    logo,
                    fit: pw.BoxFit.contain,
                    height: 60,
                  ),
                ),
                pw.SizedBox(height: 6),
              ],
              if (s.name.isNotEmpty)
                pw.Text(s.name,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
              if (s.details.isNotEmpty)
                pw.Text(s.details,
                    style: const pw.TextStyle(fontSize: 9)),
              if (s.phone.isNotEmpty)
                pw.Text('Tél : ${s.phone}',
                    style: const pw.TextStyle(fontSize: 9)),
              if (s.mf.isNotEmpty)
                pw.Text('MF : ${s.mf}',
                    style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        // Right: FACTURE label + number + date, then client info below
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('FACTURE',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('N° ${inv.number}',
              style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Date : ${formatDate(inv.date)}',
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
          pw.Text('Client :',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(inv.clientName,
              style: const pw.TextStyle(fontSize: 10)),
          if (inv.clientMf.isNotEmpty)
            pw.Text('MF : ${inv.clientMf}',
                style: const pw.TextStyle(fontSize: 9)),
          if (inv.clientDetails.isNotEmpty)
            pw.Text(inv.clientDetails,
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.right),
        ]),
      ],
    );


pw.Widget _linesTable(Invoice inv) {
  final headers = ['Qté', 'Description', 'Prix HT', 'Montant HT'];
  final rows = inv.lines
      .map((l) => [
            l.qty.toString(),
            l.desc,
            formatAmount(l.price),
            formatAmount(l.qty * l.price),
          ])
      .toList();

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    columnWidths: {
      0: const pw.FixedColumnWidth(30),
      1: const pw.FlexColumnWidth(),
      2: const pw.FixedColumnWidth(70),
      3: const pw.FixedColumnWidth(70),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey700),
        children: headers
            .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 3),
                  child: pw.Text(h,
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9)),
                ))
            .toList(),
      ),
      ...rows.asMap().entries.map((e) => pw.TableRow(
            decoration: pw.BoxDecoration(
                color: e.key.isEven ? PdfColors.grey100 : PdfColors.white),
            children: e.value
                .map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 3),
                      child: pw.Text(cell,
                          style: const pw.TextStyle(fontSize: 9)),
                    ))
                .toList(),
          )),
    ],
  );
}

pw.Widget _totalsPanel(Invoice inv, _Totals t) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 200,
        child: pw.Table(
          children: [
            _totalRow('TOTAL HT', formatAmount(t.subtotal)),
            if (inv.taxRate > 0)
              _totalRow(
                  'TVA (${inv.taxRate}%)', formatAmount(t.taxAmount)),
            if (inv.discountRate > 0)
              _totalRow('Remise (${inv.discountRate}%)',
                  '-${formatAmount(t.discountAmount)}'),
            if (inv.stampDuty > 0)
              _totalRow('Droit de timbre', formatAmount(inv.stampDuty)),
            _totalRow('Net à payer', formatAmount(t.total), bold: true),
          ],
        ),
      ),
    );

pw.TableRow _totalRow(String label, String value, {bool bold = false}) =>
    pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: pw.Text(label,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: pw.Text(value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ),
    ]);

pw.Widget _footer(AppSettings s) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(color: PdfColors.grey300),
        if (s.name.isNotEmpty)
          pw.Text(
            'Veuillez libeller tous les chèques à l\'ordre de ${s.name}',
            style: const pw.TextStyle(
                fontSize: 8, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
      ],
    );

class _Totals {
  final double subtotal, taxAmount, discountAmount, total;
  const _Totals(this.subtotal, this.taxAmount, this.discountAmount, this.total);
}

_Totals _totals(Invoice inv) {
  final sub =
      inv.lines.fold<double>(0, (s, l) => s + l.qty * l.price);
  final tax = sub * inv.taxRate / 100;
  final dis = sub * inv.discountRate / 100;
  final tot = sub + tax - dis + inv.stampDuty;
  return _Totals(sub, tax, dis, tot);
}

Future<Uint8List> buildPdfBytes(Invoice inv, AppSettings settings) async {
  final logoBytes = await loadLogo();
  final pdf = _buildPdf(inv, settings, logoBytes);
  return pdf.save();
}

// ─── Job PDF ────────────────────────────────────────────────────────────────

Future<void> shareJobPdf(Job job, AppSettings settings) async {
  final logoBytes = await loadLogo();
  final pdf = _buildJobPdf(job, settings, logoBytes);
  final bytes = await pdf.save();
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'travail-${job.client.replaceAll(' ', '_')}.pdf',
  );
}

pw.Document _buildJobPdf(Job job, AppSettings s, Uint8List? logoBytes) {
  final pdf = pw.Document();
  final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header: logo+company left, title right
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logo != null) ...[
                      pw.Container(
                        height: 60,
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Image(logo, fit: pw.BoxFit.contain, height: 60),
                      ),
                      pw.SizedBox(height: 6),
                    ],
                    if (s.name.isNotEmpty)
                      pw.Text(s.name,
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    if (s.details.isNotEmpty)
                      pw.Text(s.details, style: const pw.TextStyle(fontSize: 9)),
                    if (s.phone.isNotEmpty)
                      pw.Text('Tél : ${s.phone}', style: const pw.TextStyle(fontSize: 9)),
                    if (s.mf.isNotEmpty)
                      pw.Text('MF : ${s.mf}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('BON DE TRAVAIL',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Date : ${formatDate(job.date)}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: _jobStatusColor(job.status),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(job.status,
                      style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold)),
                ),
              ]),
            ],
          ),
          pw.SizedBox(height: 20),
          // Details box
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _jobRow('Client', job.client),
              if (job.location.isNotEmpty) _jobRow('Lieu', job.location),
              if (job.service.isNotEmpty) _jobRow('Service', job.service),
              if (job.notes.isNotEmpty) _jobRow('Notes', job.notes),
            ]),
          ),
          pw.SizedBox(height: 16),
          // Payment table
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 220,
              child: pw.Table(
                children: [
                  _totalRow('Montant total', '${formatAmount2(job.price)} TND'),
                  _totalRow('Montant reçu', '${formatAmount2(job.amountPaid)} TND'),
                  _totalRow('Restant', '${formatAmount2(job.remaining)} TND', bold: true),
                ],
              ),
            ),
          ),
          pw.Spacer(),
          _footer(s),
        ],
      ),
    ),
  );
  return pdf;
}

pw.Widget _jobRow(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
        ],
      ),
    );

PdfColor _jobStatusColor(String status) {
  switch (status) {
    case 'Terminé':
      return PdfColors.green700;
    case 'En cours':
      return PdfColors.blue700;
    case 'Annulé':
      return PdfColors.red700;
    default:
      return const PdfColor.fromInt(0xFFF59E0B);
  }
}
