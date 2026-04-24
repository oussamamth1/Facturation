import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/invoices_provider.dart';
import '../providers/products_provider.dart';
import '../providers/settings_provider.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_service.dart';
import '../utils/calculations.dart';
import '../utils/formatters.dart';
import '../theme.dart';

class InvoiceEditorScreen extends ConsumerStatefulWidget {
  final Invoice? invoice;
  // For job-to-invoice conversion
  final String? jobClient;
  final String? jobDate;
  final String? jobService;
  final double? jobPrice;

  const InvoiceEditorScreen({
    super.key,
    this.invoice,
    this.jobClient,
    this.jobDate,
    this.jobService,
    this.jobPrice,
  });

  @override
  ConsumerState<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends ConsumerState<InvoiceEditorScreen> {
  final _numberCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _clientMfCtrl = TextEditingController();
  final _clientDetailsCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '0');
  final _discountCtrl = TextEditingController(text: '0');
  final _stampCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  final List<_LineEntry> _lines = [];
  String? _editingId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    if (inv != null) {
      _editingId = inv.id;
      _numberCtrl.text = inv.number;
      _dateCtrl.text = inv.date;
      _clientNameCtrl.text = inv.clientName;
      _clientMfCtrl.text = inv.clientMf;
      _clientDetailsCtrl.text = inv.clientDetails;
      _taxCtrl.text = inv.taxRate.toString();
      _discountCtrl.text = inv.discountRate.toString();
      _stampCtrl.text = inv.stampDuty.toString();
      _notesCtrl.text = inv.notes;
      for (final l in inv.lines) {
        _lines.add(_LineEntry.fromLine(l));
      }
    } else {
      _dateCtrl.text = todayIso();
      // Job import
      if (widget.jobClient != null) {
        _clientNameCtrl.text = widget.jobClient!;
        _dateCtrl.text = widget.jobDate ?? todayIso();
        _lines.add(_LineEntry.fromLine(InvoiceLine(
          desc: widget.jobService ?? '',
          qty: 1,
          price: widget.jobPrice ?? 0,
        )));
      } else {
        _lines.add(_LineEntry.empty());
      }
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _dateCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientMfCtrl.dispose();
    _clientDetailsCtrl.dispose();
    _taxCtrl.dispose();
    _discountCtrl.dispose();
    _stampCtrl.dispose();
    _notesCtrl.dispose();
    for (final e in _lines) {
      e.dispose();
    }
    super.dispose();
  }

  InvoiceTotals get _totals => calcTotals(
        lines: _lines.map((e) => e.toLine()).toList(),
        taxRate: double.tryParse(_taxCtrl.text) ?? 0,
        discountRate: double.tryParse(_discountCtrl.text) ?? 0,
        stampDuty: double.tryParse(_stampCtrl.text) ?? 0,
      );

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final lines = _lines.map((e) => e.toLine()).toList();
    if (lines.isEmpty || lines.every((l) => l.desc.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une ligne.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final t = _totals;
      final stamp = double.tryParse(_stampCtrl.text) ?? 0;
      final inv = Invoice(
        id: _editingId ?? '',
        userId: userId,
        number: _numberCtrl.text.trim(),
        date: _dateCtrl.text.trim(),
        clientName: _clientNameCtrl.text.trim(),
        clientMf: _clientMfCtrl.text.trim(),
        clientDetails: _clientDetailsCtrl.text.trim(),
        lines: lines,
        subtotal: t.subtotal,
        taxRate: double.tryParse(_taxCtrl.text) ?? 0,
        discountRate: double.tryParse(_discountCtrl.text) ?? 0,
        taxAmount: t.taxAmount,
        discountAmount: t.discountAmount,
        stampDuty: stamp,
        total: t.total,
        notes: _notesCtrl.text.trim(),
      );
      final count = ref.read(invoicesProvider).value?.length ?? 0;
      final newId = await ref.read(invoicesServiceProvider).save(inv, userId, count);
      if (_editingId == null) setState(() => _editingId = newId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facture sauvegardée.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Invoice _buildCurrentInvoice() {
    final t = _totals;
    final stamp = double.tryParse(_stampCtrl.text) ?? 0;
    return Invoice(
      id: _editingId ?? '',
      userId: '',
      number: _numberCtrl.text.trim().isEmpty ? '—' : _numberCtrl.text.trim(),
      date: _dateCtrl.text.trim(),
      clientName: _clientNameCtrl.text.trim(),
      clientMf: _clientMfCtrl.text.trim(),
      clientDetails: _clientDetailsCtrl.text.trim(),
      lines: _lines.map((e) => e.toLine()).toList(),
      subtotal: t.subtotal,
      taxRate: double.tryParse(_taxCtrl.text) ?? 0,
      discountRate: double.tryParse(_discountCtrl.text) ?? 0,
      taxAmount: t.taxAmount,
      discountAmount: t.discountAmount,
      stampDuty: stamp,
      total: t.total,
      notes: _notesCtrl.text.trim(),
    );
  }

  Future<void> _pdf() async {
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    try {
      await downloadInvoice(_buildCurrentInvoice(), settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur PDF: $e')));
      }
    }
  }

  Future<void> _print() async {
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    try {
      await printInvoice(_buildCurrentInvoice(), settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur impression: $e')));
      }
    }
  }

  Future<void> _whatsapp() async {
    final ctrl = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('WhatsApp'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Numéro WhatsApp (ex: +21612345678)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Envoyer')),
        ],
      ),
    );
    if (phone != null && phone.isNotEmpty) {
      await sendInvoiceWhatsApp(_buildCurrentInvoice(), phone);
    }
  }

  void _fillFromClient(Client c) {
    _clientNameCtrl.text = c.name;
    _clientMfCtrl.text = c.mf;
    final parts = [c.address, c.email, c.phone].where((s) => s.isNotEmpty).join('\n');
    _clientDetailsCtrl.text = parts;
    setState(() {});
  }

  void _fillLineFromProduct(int index, Product p) {
    _lines[index].descCtrl.text = p.name;
    _lines[index].priceCtrl.text = p.price.toString();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider).value ?? [];
    final products = ref.watch(productsProvider).value ?? [];
    final t = _totals;
    final stamp = double.tryParse(_stampCtrl.text) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId == null ? 'Nouvelle facture' : 'Facture N° ${_numberCtrl.text}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Imprimer',
            onPressed: _print,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Télécharger PDF',
            onPressed: _pdf,
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined),
            tooltip: 'Envoyer WhatsApp',
            onPressed: _whatsapp,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Client selector
          if (clients.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.people_outline, size: 18, color: kBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Client>(
                        isExpanded: true,
                        hint: const Text('Sélectionner un client du répertoire',
                            style: TextStyle(fontSize: 13, color: kSlate500)),
                        items: clients
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (c) {
                          if (c != null) _fillFromClient(c);
                        },
                        value: null,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          // Invoice header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _numberCtrl,
                      decoration: const InputDecoration(labelText: 'N° Facture'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(_dateCtrl.text) ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          _dateCtrl.text =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                          setState(() {});
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _dateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            suffixIcon: Icon(Icons.calendar_today, size: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: _clientNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom du client'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _clientMfCtrl,
                  decoration: const InputDecoration(labelText: 'MF Client'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _clientDetailsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Adresse / Détails client'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Line items
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Articles',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 8),
                ..._lines.asMap().entries.map((e) {
                  final idx = e.key;
                  final entry = e.value;
                  return _LineItemRow(
                    entry: entry,
                    products: products,
                    onChanged: () => setState(() {}),
                    onRemove: _lines.length > 1
                        ? () => setState(() {
                              entry.dispose();
                              _lines.removeAt(idx);
                            })
                        : null,
                    onProductSelected: (p) => _fillLineFromProduct(idx, p),
                  );
                }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter une ligne'),
                    onPressed: () => setState(() => _lines.add(_LineEntry.empty())),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Totals
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text('Totaux',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                _totalRow('TOTAL HT', '${formatAmount(t.subtotal)} TND'),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(
                      child: Text('TVA (%)', style: TextStyle(fontSize: 13))),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _taxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.all(8)),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: Text(
                      '${formatAmount(t.taxAmount)} TND',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, color: kSlate700),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(
                      child: Text('Remise (%)', style: TextStyle(fontSize: 13))),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.all(8)),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: Text(
                      '-${formatAmount(t.discountAmount)} TND',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, color: kSlate700),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(
                      child: Text('Droit de timbre', style: TextStyle(fontSize: 13))),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _stampCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.all(8)),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: Text(
                      '${formatAmount(stamp)} TND',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, color: kSlate700),
                    ),
                  ),
                ]),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Net à payer',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: kSlate900)),
                    Text('${formatAmount(t.total)} TND',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: kBlue)),
                  ],
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Notes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes internes',
                  prefixIcon: Icon(Icons.notes_outlined, size: 18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_outlined),
        label: const Text('Sauvegarder'),
      ),
    );
  }

  Widget _totalRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: kSlate700)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, color: kSlate900, fontWeight: FontWeight.w600)),
        ],
      );
}

// ------- Line item row widget -------

class _LineItemRow extends StatelessWidget {
  final _LineEntry entry;
  final List<Product> products;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final void Function(Product) onProductSelected;

  const _LineItemRow({
    required this.entry,
    required this.products,
    required this.onChanged,
    required this.onRemove,
    required this.onProductSelected,
  });

  @override
  Widget build(BuildContext context) {
    final qty = int.tryParse(entry.qtyCtrl.text) ?? 0;
    final price = double.tryParse(entry.priceCtrl.text) ?? 0;
    final amount = qty * price;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kSlate200),
      ),
      child: Column(children: [
        // Description with product autocomplete
        Row(children: [
          Expanded(
            child: Autocomplete<Product>(
              displayStringForOption: (p) => p.name,
              optionsBuilder: (v) => products
                  .where((p) =>
                      p.name.toLowerCase().contains(v.text.toLowerCase()))
                  .toList(),
              onSelected: (p) {
                onProductSelected(p);
                onChanged();
              },
              fieldViewBuilder: (ctx, fieldCtrl, focusNode, onFieldSubmitted) {
                // Sync external controller with autocomplete field controller
                fieldCtrl.text = entry.descCtrl.text;
                fieldCtrl.addListener(() {
                  entry.descCtrl.text = fieldCtrl.text;
                  onChanged();
                });
                return TextField(
                  controller: fieldCtrl,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    isDense: true,
                  ),
                );
              },
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: kRed, size: 20),
              onPressed: onRemove,
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          SizedBox(
            width: 60,
            child: TextField(
              controller: entry.qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Qté', isDense: true),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: entry.priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Prix HT', isDense: true),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Montant', style: TextStyle(fontSize: 10, color: kSlate500)),
            Text(
              formatAmount(amount),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ]),
        ]),
      ]),
    );
  }
}

// ------- Mutable line state -------

class _LineEntry {
  final TextEditingController descCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _LineEntry({
    required this.descCtrl,
    required this.qtyCtrl,
    required this.priceCtrl,
  });

  factory _LineEntry.empty() => _LineEntry(
        descCtrl: TextEditingController(),
        qtyCtrl: TextEditingController(text: '1'),
        priceCtrl: TextEditingController(),
      );

  factory _LineEntry.fromLine(InvoiceLine l) => _LineEntry(
        descCtrl: TextEditingController(text: l.desc),
        qtyCtrl: TextEditingController(text: l.qty.toString()),
        priceCtrl: TextEditingController(text: l.price == 0 ? '' : l.price.toString()),
      );

  InvoiceLine toLine() => InvoiceLine(
        desc: descCtrl.text.trim(),
        qty: int.tryParse(qtyCtrl.text) ?? 1,
        price: double.tryParse(priceCtrl.text) ?? 0,
      );

  void dispose() {
    descCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}
