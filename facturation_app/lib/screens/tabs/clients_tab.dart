import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clients_provider.dart';
import '../../theme.dart';

class ClientsTab extends ConsumerStatefulWidget {
  const ClientsTab({super.key});

  @override
  ConsumerState<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends ConsumerState<ClientsTab> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _mfCtrl = TextEditingController();
  String? _editingId;
  String _search = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _mfCtrl.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() => _editingId = null);
    _nameCtrl.clear();
    _addressCtrl.clear();
    _emailCtrl.clear();
    _phoneCtrl.clear();
    _mfCtrl.clear();
  }

  void _load(Client c) {
    setState(() => _editingId = c.id);
    _nameCtrl.text = c.name;
    _addressCtrl.text = c.address;
    _emailCtrl.text = c.email;
    _phoneCtrl.text = c.phone;
    _mfCtrl.text = c.mf;
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Le nom est obligatoire.')));
      return;
    }
    final userId = ref.read(currentUserIdProvider)!;
    final c = Client(
      id: _editingId ?? '',
      userId: userId,
      name: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      mf: _mfCtrl.text.trim(),
    );
    await ref.read(clientsServiceProvider).save(c, userId);
    _clear();
  }

  Future<void> _delete(Client c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce client ?'),
        content: Text(c.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true) await ref.read(clientsServiceProvider).delete(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final clients = clientsAsync.value ?? [];
    final filtered = _search.isEmpty
        ? clients
        : clients
            .where((c) => c.name.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Form
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _editingId == null ? 'Nouveau client' : 'Modifier client',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  if (_editingId != null)
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Nouveau'),
                      onPressed: _clear,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _field(_nameCtrl, 'Nom *', Icons.person_outline),
              const SizedBox(height: 8),
              _field(_addressCtrl, 'Adresse', Icons.location_on_outlined, maxLines: 2),
              const SizedBox(height: 8),
              _field(_emailCtrl, 'Email', Icons.email_outlined,
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 8),
              _field(_phoneCtrl, 'Téléphone', Icons.phone_outlined,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 8),
              _field(_mfCtrl, 'MF (Matricule Fiscal)', Icons.badge_outlined),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Sauvegarder'),
                  onPressed: _save,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // List
        Card(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Rechercher un client...',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            if (clientsAsync.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucun client.', style: TextStyle(color: kSlate500)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: kSlate200),
                itemBuilder: (_, i) {
                  final c = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: kBlue.withValues(alpha: 0.1),
                      child: Text(c.name[0].toUpperCase(),
                          style: const TextStyle(color: kBlue, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(c.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: c.phone.isNotEmpty ? Text(c.phone) : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: kRed, size: 20),
                      onPressed: () => _delete(c),
                    ),
                    onTap: () => _load(c),
                  );
                },
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
        ),
      );
}
