import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/worker_profile.dart';
import '../models/job_request.dart';
import '../providers/marketplace_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class JobRequestScreen extends ConsumerStatefulWidget {
  final WorkerProfile worker;

  const JobRequestScreen({super.key, required this.worker});

  @override
  ConsumerState<JobRequestScreen> createState() => _JobRequestScreenState();
}

class _JobRequestScreenState extends ConsumerState<JobRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String? _selectedService;
  bool _sending = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    final userId = ref.read(currentUserIdProvider)!;
    final settings = ref.read(settingsProvider).value;
    final clientName = settings?.name.isNotEmpty == true
        ? settings!.name
        : ref.read(currentUserProvider)?.email ?? 'Client';
    final request = JobRequest(
      id: '',
      clientId: userId,
      clientName: clientName,
      workerId: widget.worker.userId,
      workerName: widget.worker.name,
      service: _selectedService ?? widget.worker.services.first,
      description: _descCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
    );
    await ref.read(marketplaceServiceProvider).sendJobRequest(request);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande envoyée avec succès !')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.worker.services;
    _selectedService ??= services.isNotEmpty ? services.first : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Envoyer une demande')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Worker summary card
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(widget.worker.name.isNotEmpty
                      ? widget.worker.name[0].toUpperCase()
                      : '?'),
                ),
                title: Text(widget.worker.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(widget.worker.services.join(' • ')),
              ),
            ),
            const SizedBox(height: 16),
            if (services.length > 1) ...[
              const Text('Service demandé',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: services.map((s) {
                  return ChoiceChip(
                    label: Text(s),
                    selected: _selectedService == s,
                    onSelected: (_) => setState(() => _selectedService = s),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Adresse / Lieu',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description du problème *',
                hintText: 'Décrivez le travail à effectuer...',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: const Text('Envoyer la demande'),
            ),
          ],
        ),
      ),
    );
  }
}
