import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/invoice.dart';
import '../../providers/invoices_provider.dart';
import '../../utils/formatters.dart';
import '../../theme.dart';
import '../invoice_editor_screen.dart';

// ── Period presets ──
enum _Period { all, week, month, lastMonth, year, custom }

extension _PeriodLabel on _Period {
  String get label {
    switch (this) {
      case _Period.all:       return 'Tous';
      case _Period.week:      return 'Cette semaine';
      case _Period.month:     return 'Ce mois';
      case _Period.lastMonth: return 'Mois dernier';
      case _Period.year:      return 'Cette année';
      case _Period.custom:    return 'Personnalisé';
    }
  }
}

class InvoicesTab extends ConsumerStatefulWidget {
  const InvoicesTab({super.key});

  @override
  ConsumerState<InvoicesTab> createState() => _InvoicesTabState();
}

const _kPageSize = 5;

class _InvoicesTabState extends ConsumerState<InvoicesTab> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  String _search = '';
  int _visibleCount = _kPageSize;
  _Period _period = _Period.all;
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        setState(() => _visibleCount += _kPageSize);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Returns [from, to] ISO strings for the current period (null = unbounded)
  List<String?> get _dateRange {
    final now = DateTime.now();
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    switch (_period) {
      case _Period.all:
        return [null, null];

      case _Period.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return [iso(monday), iso(sunday)];

      case _Period.month:
        final first = DateTime(now.year, now.month, 1);
        final last = DateTime(now.year, now.month + 1, 0);
        return [iso(first), iso(last)];

      case _Period.lastMonth:
        final first = DateTime(now.year, now.month - 1, 1);
        final last = DateTime(now.year, now.month, 0);
        return [iso(first), iso(last)];

      case _Period.year:
        return ['${now.year}-01-01', '${now.year}-12-31'];

      case _Period.custom:
        String? from, to;
        if (_customFrom != null) from = iso(_customFrom!);
        if (_customTo != null) to = iso(_customTo!);
        return [from, to];
    }
  }

  void _setPeriod(_Period p) {
    setState(() {
      _period = p;
      _visibleCount = _kPageSize;
    });
  }

  Future<void> _pickCustomFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _customFrom = picked;
        _period = _Period.custom;
        _visibleCount = _kPageSize;
        if (_customTo != null && _customTo!.isBefore(picked)) {
          _customTo = null;
        }
      });
    }
  }

  Future<void> _pickCustomTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customTo ?? (_customFrom ?? DateTime.now()),
      firstDate: _customFrom ?? DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _customTo = picked;
        _period = _Period.custom;
        _visibleCount = _kPageSize;
      });
    }
  }

  void _clearAll() {
    _searchCtrl.clear();
    setState(() {
      _search = '';
      _period = _Period.all;
      _customFrom = null;
      _customTo = null;
      _visibleCount = _kPageSize;
    });
  }

  Future<void> _delete(Invoice inv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette facture ?'),
        content: Text('N° ${inv.number} — ${inv.clientName}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Supprimer', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true) await ref.read(invoicesServiceProvider).delete(inv.id);
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final invoices = invoicesAsync.value ?? [];

    // Search filter
    var filtered = _search.isEmpty
        ? invoices
        : invoices
            .where((inv) =>
                inv.clientName
                    .toLowerCase()
                    .contains(_search.toLowerCase()) ||
                inv.number.contains(_search))
            .toList();

    // Date range filter
    final range = _dateRange;
    final fromStr = range[0];
    final toStr = range[1];
    if (fromStr != null) {
      filtered =
          filtered.where((inv) => inv.date.compareTo(fromStr) >= 0).toList();
    }
    if (toStr != null) {
      filtered =
          filtered.where((inv) => inv.date.compareTo(toStr) <= 0).toList();
    }

    final visible = filtered.take(_visibleCount).toList();
    final hasMore = filtered.length > _visibleCount;
    final grandTotal =
        filtered.fold<double>(0, (s, inv) => s + inv.total);
    final hasActiveFilter =
        _search.isNotEmpty || _period != _Period.all;

    return Scaffold(
      body: Column(children: [
        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Rechercher par client ou numéro...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _search = '';
                          _visibleCount = _kPageSize;
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() {
              _search = v;
              _visibleCount = _kPageSize;
            }),
          ),
        ),

        // ── Period preset chips ──
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _Period.values
                .where((p) => p != _Period.custom)
                .map((p) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _PeriodChip(
                        label: p.label,
                        selected: _period == p,
                        onTap: () => _setPeriod(p),
                      ),
                    ))
                .toList(),
          ),
        ),

        // ── Custom date pickers (only shown when custom selected) ──
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _period == _Period.custom
              ? Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(children: [
                    Expanded(
                      child: _DateBtn(
                        label: 'De',
                        value: _customFrom,
                        onTap: _pickCustomFrom,
                        onClear: _customFrom != null
                            ? () => setState(() {
                                  _customFrom = null;
                                  _visibleCount = _kPageSize;
                                })
                            : null,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward,
                          size: 16, color: kSlate500),
                    ),
                    Expanded(
                      child: _DateBtn(
                        label: 'À',
                        value: _customTo,
                        onTap: _pickCustomTo,
                        onClear: _customTo != null
                            ? () => setState(() {
                                  _customTo = null;
                                  _visibleCount = _kPageSize;
                                })
                            : null,
                      ),
                    ),
                  ]),
                )
              : const SizedBox.shrink(),
        ),

        // ── Result summary bar ──
        if (invoices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: kBlue.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                const Icon(Icons.receipt_long,
                    size: 15, color: kBlue),
                const SizedBox(width: 8),
                Text(
                  filtered.isEmpty
                      ? 'Aucun résultat'
                      : '${filtered.length} facture${filtered.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: kSlate700),
                ),
                const Spacer(),
                if (filtered.isNotEmpty) ...[
                  const Text('Total : ',
                      style: TextStyle(
                          fontSize: 12, color: kSlate700)),
                  Text('${formatAmount(grandTotal)} TND',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kBlue)),
                ],
                if (hasActiveFilter) ...[
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _clearAll,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: kRed.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.close,
                                size: 12, color: kRed),
                            SizedBox(width: 3),
                            Text('Effacer',
                                style: TextStyle(
                                    fontSize: 11, color: kRed)),
                          ]),
                    ),
                  ),
                ],
              ]),
            ),
          ),

        const SizedBox(height: 10),

        // ── Invoice list ──
        Expanded(
          child: invoicesAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_outlined,
                              size: 48,
                              color: kSlate500.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          const Text('Aucune facture trouvée.',
                              style: TextStyle(color: kSlate500)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollCtrl,
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount:
                          visible.length + (hasMore ? 1 : 0),
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        if (i == visible.length) {
                          return const Padding(
                            padding:
                                EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          );
                        }
                        final inv = visible[i];
                        return _InvoiceCard(
                          invoice: inv,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    InvoiceEditorScreen(
                                        invoice: inv)),
                          ),
                          onDelete: () => _delete(inv),
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
          MaterialPageRoute(
              builder: (_) => const InvoiceEditorScreen()),
        ),
      ),
    );
  }
}

// ── Invoice card ──

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _InvoiceCard({
    required this.invoice,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kSlate200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_outlined,
                color: Color(0xFF6366F1), size: 22),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('N° ${invoice.number}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: kSlate900)),
                  const SizedBox(height: 2),
                  Text(invoice.clientName,
                      style: const TextStyle(
                          color: kSlate500, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.calendar_today,
                        size: 11, color: kSlate500),
                    const SizedBox(width: 3),
                    Text(formatDate(invoice.date),
                        style: const TextStyle(
                            color: kSlate500, fontSize: 11)),
                  ]),
                ]),
          ),
          // Total badge + delete
          Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF6366F1)
                            .withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '${formatAmount(invoice.total)} TND',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFF4F46E5)),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline,
                        color: kRed, size: 18),
                  ),
                ),
              ]),
        ]),
      ),
    );
  }
}

// ── Period chip ──

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF6366F1)
                : const Color(0xFF6366F1).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF6366F1).withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : const Color(0xFF6366F1),
            ),
          ),
        ),
      );
}

// ── Custom date button ──

class _DateBtn extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateBtn({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: hasValue
              ? const Color(0xFF6366F1).withValues(alpha: 0.07)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasValue
                ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                : kSlate200,
          ),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today,
              size: 14,
              color: hasValue
                  ? const Color(0xFF6366F1)
                  : kSlate500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hasValue
                  ? '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}'
                  : label,
              style: TextStyle(
                  fontSize: 12,
                  color: hasValue
                      ? const Color(0xFF6366F1)
                      : kSlate500,
                  fontWeight: hasValue
                      ? FontWeight.w600
                      : FontWeight.normal),
            ),
          ),
          if (hasValue && onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close,
                  size: 14, color: Color(0xFF6366F1)),
            ),
        ]),
      ),
    );
  }
}
