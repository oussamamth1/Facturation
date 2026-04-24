import 'package:url_launcher/url_launcher.dart';
import '../models/invoice.dart';
import '../utils/formatters.dart';

Future<void> sendInvoiceWhatsApp(Invoice inv, String phone) async {
  final lines = inv.lines.map((l) {
    final total = formatAmount(l.qty * l.price);
    return '- ${l.desc} : ${l.qty} × ${formatAmount(l.price)} = $total TND';
  }).join('\n');

  final buf = StringBuffer();
  buf.writeln('📄 FACTURE N° ${inv.number}');
  buf.writeln('📅 Date : ${formatDate(inv.date)}');
  buf.writeln('👤 Client : ${inv.clientName}');
  buf.writeln('');
  buf.writeln('Articles :');
  buf.writeln(lines);
  buf.writeln('');
  buf.writeln('TOTAL HT : ${formatAmount(inv.subtotal)} TND');
  if (inv.taxRate > 0) {
    buf.writeln('TVA (${inv.taxRate}%) : ${formatAmount(inv.taxAmount)} TND');
  }
  if (inv.discountRate > 0) {
    buf.writeln('Remise (${inv.discountRate}%) : -${formatAmount(inv.discountAmount)} TND');
  }
  if (inv.stampDuty > 0) {
    buf.writeln('Droit de timbre : ${formatAmount(inv.stampDuty)} TND');
  }
  buf.writeln('💰 Net à payer : ${formatAmount(inv.total)} TND');
  if (inv.notes.isNotEmpty) {
    buf.writeln('');
    buf.writeln('Notes : ${inv.notes}');
  }

  final encoded = Uri.encodeComponent(buf.toString());
  final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri.parse('https://wa.me/$clean?text=$encoded');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
