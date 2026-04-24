import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/invoice.dart';
import '../../providers/invoices_provider.dart';
import '../../utils/formatters.dart';
import '../../theme.dart';
import '../invoice_editor_screen.dart';

class InvoicesTab extends ConsumerStatefulWidget {
  const InvoicesTab({super.key});

  @override
  ConsumerState<InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends ConsumerState<InvoicesTab> {
  String _search = '';

  Future<void> _delete(Invoice inv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette facture ?'),
        content: Text('N° ${inv.number} — ${inv.clientName}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true) await ref.read(invoicesServiceProvider).delete(inv.id);
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final invoices = invoicesAsync.value ?? [];
    final filtered = _search.isEmpty
        ? invoices
        : invoices
            .where((inv) =>
                inv.clientName.toLowerCase().contains(_search.toLowerCase()) ||
                inv.number.contains(_search))
            .toList();

    return Scaffold(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher par client ou numéro...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: invoicesAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const Center(
                      child: Text('Aucune facture.',
                          style: TextStyle(color: kSlate500)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final inv = filtered[i];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              child: const Icon(Icons.receipt,
                                  color: Color(0xFF6366F1), size: 20),
                            ),
                            title: Text(
                              'N° ${inv.number}  •  ${formatDate(inv.date)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(inv.clientName,
                                    style: const TextStyle(
                                        color: kSlate700, fontSize: 12),
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                  '${formatAmount(inv.total)} TND',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: kBlue,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: kRed, size: 20),
                              onPressed: () => _delete(inv),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => InvoiceEditorScreen(invoice: inv)),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle facture'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InvoiceEditorScreen()),
        ),
      ),
    );
  }
}
