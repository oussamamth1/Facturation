import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/clients_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/invoices_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../utils/formatters.dart';
import '../../theme.dart';

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
    final products = ref.watch(productsProvider);
    final invoices = ref.watch(invoicesProvider);
    final jobs = ref.watch(jobsProvider);

    final clientCount = clients.value?.length ?? 0;
    final productCount = products.value?.length ?? 0;
    final invoiceCount = invoices.value?.length ?? 0;
    final jobCount = jobs.value?.length ?? 0;
    final lastInvoice = invoices.value?.isNotEmpty == true ? invoices.value!.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Stats grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _StatCard(
              label: 'Clients',
              count: clientCount,
              icon: Icons.people,
              gradient: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
            ),
            _StatCard(
              label: 'Produits',
              count: productCount,
              icon: Icons.inventory_2,
              gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
            ),
            _StatCard(
              label: 'Factures',
              count: invoiceCount,
              icon: Icons.receipt,
              gradient: const [Color(0xFF6366F1), Color(0xFF818CF8)],
            ),
            _StatCard(
              label: 'Travaux',
              count: jobCount,
              icon: Icons.work,
              gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
            ),
          ],
        ),
     //   const SizedBox(height: 16),
        // Last invoice
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.receipt_long, size: 18, color: kBlue),
                SizedBox(width: 6),
                Text('Dernière facture',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: kSlate900)),
              ]),
              const SizedBox(height: 12),
              if (lastInvoice == null)
                const Text('Aucune facture enregistrée.',
                    style: TextStyle(color: kSlate500))
              else ...[
                _row('N°', lastInvoice.number),
                _row('Date', formatDate(lastInvoice.date)),
                _row('Client', lastInvoice.clientName),
                _row('Total HT', '${formatAmount(lastInvoice.subtotal)} TND'),
                _row('Net à payer', '${formatAmount(lastInvoice.total)} TND',
                    bold: true),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: kSlate500, fontSize: 13)),
            Text(value,
                style: TextStyle(
                    color: kSlate900,
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          ],
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final List<Color> gradient;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
              ),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
            ]),
          ],
        ),
      );
}
