import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client.dart';
import '../models/job.dart';
import '../providers/auth_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/jobs_provider.dart';
import '../utils/formatters.dart';
import '../theme.dart';
import 'invoice_editor_screen.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsProvider);
    final jobs = jobsAsync.value ?? [];
    final filtered = _search.isEmpty
        ? jobs
        : jobs
            .where((j) => j.client.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    final totalPrice = jobs.fold<double>(0, (s, j) => s + j.price);
    final totalPaid = jobs.fold<double>(0, (s, j) => s + j.amountPaid);
    final totalRemaining = totalPrice - totalPaid;

    return Scaffold(
      body: Column(children: [
        // Summary strip
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summary('Total', formatAmount2(totalPrice), kSlate700),
              _summary('Reçu', formatAmount2(totalPaid), kGreen),
              _summary('Restant', formatAmount2(totalRemaining), kRed),
            ],
          ),
        ),
        const Divider(height: 1),
        // Search
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher par client...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        // List
        Expanded(
          child: jobsAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const Center(
                      child: Text('Aucun travail.', style: TextStyle(color: kSlate500)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _JobCard(job: filtered[i]),
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nouveau travail'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JobEditorScreen()),
        ),
      ),
    );
  }

  Widget _summary(String label, String value, Color color) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: kSlate500)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13, color: color)),
        ],
      );
}

class _JobCard extends ConsumerWidget {
  final Job job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(job.status);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobEditorScreen(job: job)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(job.client,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(job.status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (job.service.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(job.service,
                    style: const TextStyle(color: kSlate500, fontSize: 13)),
              ),
            if (job.location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: kSlate500),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(job.location,
                        style: const TextStyle(color: kSlate500, fontSize: 12)),
                  ),
                ]),
              ),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.calendar_today, size: 13, color: kSlate500),
              const SizedBox(width: 4),
              Text(formatDate(job.date),
                  style: const TextStyle(color: kSlate500, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _amountChip('Total', job.price, kSlate700),
                _amountChip('Reçu', job.amountPaid, kGreen),
                _amountChip('Reste', job.remaining, kRed),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_outlined, size: 15),
                  label: const Text('Créer facture', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoiceEditorScreen(
                        jobClient: job.client,
                        jobDate: job.date,
                        jobService: job.service,
                        jobPrice: job.price,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: kRed, size: 20),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Supprimer ce travail ?'),
                      content: Text(job.client),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Annuler')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Supprimer',
                                style: TextStyle(color: kRed))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref.read(jobsServiceProvider).delete(job.id);
                  }
                },
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _amountChip(String label, double value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: kSlate500)),
          Text(
            '${formatAmount2(value)} TND',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );

  Color _statusColor(String status) {
    switch (status) {
      case 'Terminé':
        return kGreen;
      case 'En cours':
        return kBlue;
      case 'Annulé':
        return kRed;
      default:
        return const Color(0xFFF59E0B);
    }
  }
}

// ------- Job Editor -------

class JobEditorScreen extends ConsumerStatefulWidget {
  final Job? job;
  const JobEditorScreen({super.key, this.job});

  @override
  ConsumerState<JobEditorScreen> createState() => _JobEditorScreenState();
}

class _JobEditorScreenState extends ConsumerState<JobEditorScreen> {
  final _clientCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _serviceCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  String _status = 'Planifié';
  String? _editingId;
  bool _saving = false;

  static const _statuses = ['Planifié', 'En cours', 'Terminé', 'Annulé'];

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    if (j != null) {
      _editingId = j.id;
      _clientCtrl.text = j.client;
      _locationCtrl.text = j.location;
      _serviceCtrl.text = j.service;
      _priceCtrl.text = j.price == 0 ? '' : j.price.toString();
      _dateCtrl.text = j.date;
      _paidCtrl.text = j.amountPaid.toString();
      _notesCtrl.text = j.notes;
      _status = j.status;
    } else {
      _dateCtrl.text = todayIso();
    }
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    _locationCtrl.dispose();
    _serviceCtrl.dispose();
    _priceCtrl.dispose();
    _dateCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _remaining =>
      (double.tryParse(_priceCtrl.text) ?? 0) -
      (double.tryParse(_paidCtrl.text) ?? 0);

  Future<void> _save() async {
    if (_clientCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le client est obligatoire.')));
      return;
    }
    final userId = ref.read(currentUserIdProvider)!;
    setState(() => _saving = true);
    try {
      final j = Job(
        id: _editingId ?? '',
        userId: userId,
        client: _clientCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        service: _serviceCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text) ?? 0,
        date: _dateCtrl.text.trim(),
        status: _status,
        notes: _notesCtrl.text.trim(),
        amountPaid: double.tryParse(_paidCtrl.text) ?? 0,
      );
      await ref.read(jobsServiceProvider).save(j, userId);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider).value ?? [];
    final clientNames = clients.map((c) => c.name).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId == null ? 'Nouveau travail' : 'Modifier travail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Client autocomplete
                Autocomplete<String>(
                  displayStringForOption: (s) => s,
                  optionsBuilder: (v) => clientNames
                      .where((n) =>
                          n.toLowerCase().contains(v.text.toLowerCase()))
                      .toList(),
                  onSelected: (name) {
                    _clientCtrl.text = name;
                    // Auto-fill location from client address
                    final c = clients.firstWhere((c) => c.name == name,
                        orElse: () => const Client(id: '', userId: '', name: ''));
                    if (c.address.isNotEmpty && _locationCtrl.text.isEmpty) {
                      _locationCtrl.text = c.address;
                      setState(() {});
                    }
                  },
                  fieldViewBuilder: (ctx, fieldCtrl, focusNode, onSubmitted) {
                    fieldCtrl.text = _clientCtrl.text;
                    fieldCtrl.addListener(() {
                      _clientCtrl.text = fieldCtrl.text;
                    });
                    return TextField(
                      controller: fieldCtrl,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Client *',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _locationCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Lieu / Adresse',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _serviceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Service / Prestation',
                    prefixIcon: Icon(Icons.build_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Montant total (TND)',
                        prefixIcon: Icon(Icons.attach_money, size: 18),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                            prefixIcon: Icon(Icons.calendar_today, size: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _paidCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Montant reçu (TND)',
                        prefixIcon: Icon(Icons.payments_outlined, size: 18),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Restant',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                      ),
                      child: Text(
                        '${formatAmount2(_remaining)} TND',
                        style: TextStyle(
                          color: _remaining > 0 ? kRed : kGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Statut',
                    prefixIcon: Icon(Icons.flag_outlined, size: 18),
                  ),
                  items: _statuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: Icon(Icons.notes_outlined, size: 18),
                  ),
                ),
              ]),
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
}
