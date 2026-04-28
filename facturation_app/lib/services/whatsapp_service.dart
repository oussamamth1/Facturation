import 'package:url_launcher/url_launcher.dart';
import '../models/invoice.dart';
import '../models/job.dart';
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

Future<void> sendJobWhatsAppText(Job job, String phone) async {
  final buf = StringBuffer();
  buf.writeln('🔧 BON DE TRAVAIL');
  buf.writeln('');
  buf.writeln('👤 Client : ${job.client}');
  if (job.location.isNotEmpty) buf.writeln('📍 Lieu : ${job.location}');
  if (job.service.isNotEmpty) buf.writeln('🛠 Service : ${job.service}');
  buf.writeln('📅 Date : ${formatDate(job.date)}');
  buf.writeln('📋 Statut : ${job.status}');
  buf.writeln('');
  buf.writeln('💰 Montant total : ${formatAmount2(job.price)} TND');
  buf.writeln('✅ Montant reçu : ${formatAmount2(job.amountPaid)} TND');
  if (job.remaining > 0) {
    buf.writeln('⏳ Restant : ${formatAmount2(job.remaining)} TND');
  }
  if (job.notes.isNotEmpty) {
    buf.writeln('');
    buf.writeln('Notes : ${job.notes}');
  }

  final encoded = Uri.encodeComponent(buf.toString());
  final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri.parse('https://wa.me/$clean?text=$encoded');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> callPhone(String phone) async {
  final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
  final uri = Uri.parse('tel:$clean');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
