import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/categories_provider.dart';
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
    final settings = ref.read(settingsProvider).valueOrNull ?? const AppSettings();
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
    final settings = ref.read(settingsProvider).valueOrNull ?? const AppSettings();
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
        title: const Text('Envoyer par WhatsApp'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Numéro (ex: +21612345678)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    ctrl.dispose();
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
    final categories = ref.watch(categoriesProvider).value ?? [];
    ref.watch(settingsProvider); // keep stream alive so ref.read works in _pdf/_print
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    categories: categories,
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
  final List<dynamic> categories;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final void Function(Product) onProductSelected;

  const _LineItemRow({
    required this.entry,
    required this.products,
    required this.categories,
    required this.onChanged,
    required this.onRemove,
    required this.onProductSelected,
  });

  Future<void> _openPicker(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductPickerSheet(
          products: products, categoryNames: categories.map((c) => c.name as String).toList()),
    );
    if (product != null) {
      onProductSelected(product);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final qty = int.tryParse(entry.qtyCtrl.text) ?? 0;
    final price = double.tryParse(entry.priceCtrl.text) ?? 0;
    final amount = qty * price;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSlate200),
      ),
      child: Column(children: [
        // Description row
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: entry.descCtrl,
              decoration: InputDecoration(
                labelText: 'Description',
                isDense: true,
                suffixIcon: products.isNotEmpty
                    ? Tooltip(
                        message: 'Choisir depuis le catalogue',
                        child: IconButton(
                          icon: const Icon(Icons.inventory_2_outlined,
                              size: 18, color: kBlue),
                          onPressed: () => _openPicker(context),
                        ),
                      )
                    : null,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: kRed, size: 20),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        // Qty / price / amount row
        Row(children: [
          SizedBox(
            width: 60,
            child: TextField(
              controller: entry.qtyCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Qté', isDense: true),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: entry.priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Prix HT', isDense: true),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Montant',
                      style:
                          TextStyle(fontSize: 9, color: kSlate500)),
                  Text(
                    '${formatAmount(amount)} TND',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: kBlue),
                  ),
                ]),
          ),
        ]),
      ]),
    );
  }
}

// ------- Product picker bottom sheet -------

class _ProductPickerSheet extends StatefulWidget {
  final List<Product> products;
  final List<String> categoryNames;
  const _ProductPickerSheet(
      {required this.products, required this.categoryNames});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedCategory = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = widget.categoryNames;

    var filtered = widget.products;
    if (_selectedCategory.isNotEmpty) {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q))
          .toList();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Column(children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: kSlate200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(children: [
            const Icon(Icons.inventory_2_outlined, color: kBlue, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Catalogue articles',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: kSlate900)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Saisie manuelle',
                  style: TextStyle(fontSize: 12)),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _searchCtrl,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Rechercher un article...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        // Category filter chips
        if (allCategories.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _PickerCategoryChip(
                  label: 'Tous',
                  selected: _selectedCategory.isEmpty,
                  onTap: () => setState(() => _selectedCategory = ''),
                ),
                const SizedBox(width: 6),
                ...allCategories.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _PickerCategoryChip(
                        label: cat,
                        selected: _selectedCategory == cat,
                        onTap: () => setState(() =>
                            _selectedCategory =
                                _selectedCategory == cat ? '' : cat),
                      ),
                    )),
              ],
            ),
          ),
        if (allCategories.isNotEmpty) const SizedBox(height: 8),
        const Divider(height: 1),
        // Product list
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('Aucun article trouvé.',
                      style: TextStyle(color: kSlate500)))
              : ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    return InkWell(
                      onTap: () => Navigator.pop(context, p),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kSlate200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: kBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory_2_outlined,
                                color: kBlue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  if (p.description.isNotEmpty)
                                    Text(p.description,
                                        style: const TextStyle(
                                            color: kSlate500, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  if (p.category.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: kBlue.withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(p.category,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: kBlue,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                ]),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: kGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${formatAmount(p.price)} TND',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kGreen,
                                  fontSize: 12),
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _PickerCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PickerCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? kBlue : kBlue.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? kBlue : kBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : kBlue,
            ),
          ),
        ),
      );
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
