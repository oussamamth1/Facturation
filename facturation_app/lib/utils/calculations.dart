import '../models/invoice.dart';

class InvoiceTotals {
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double total;

  const InvoiceTotals({
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.total,
  });
}

InvoiceTotals calcTotals({
  required List<InvoiceLine> lines,
  required double taxRate,
  required double discountRate,
  required double stampDuty,
}) {
  final subtotal = lines.fold<double>(0, (s, l) => s + l.qty * l.price);
  final taxAmount = subtotal * taxRate / 100;
  final discountAmount = subtotal * discountRate / 100;
  final total = subtotal + taxAmount - discountAmount + stampDuty;
  return InvoiceTotals(
    subtotal: subtotal,
    taxAmount: taxAmount,
    discountAmount: discountAmount,
    total: total,
  );
}
