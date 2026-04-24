import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_settings.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/logo_service.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _mfCtrl = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _detailsCtrl.dispose();
    _phoneCtrl.dispose();
    _mfCtrl.dispose();
    super.dispose();
  }

  void _populate(AppSettings s) {
    if (_loaded) return;
    _nameCtrl.text = s.name;
    _detailsCtrl.text = s.details;
    _phoneCtrl.text = s.phone;
    _mfCtrl.text = s.mf;
    _loaded = true;
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final s = AppSettings(
      name: _nameCtrl.text.trim(),
      details: _detailsCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      mf: _mfCtrl.text.trim(),
    );
    await ref.read(settingsServiceProvider).save(s, userId);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Paramètres sauvegardés.')));
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 400,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await ref.read(logoProvider.notifier).update(bytes);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Logo sauvegardé.')));
    }
  }

  Future<void> _removeLogo() async {
    await ref.read(logoProvider.notifier).remove();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    settingsAsync.whenData(_populate);
    final logoBytes = ref.watch(logoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres entreprise')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Logo section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.image_outlined, size: 18, color: kBlue),
                    SizedBox(width: 6),
                    Text('Logo de l\'entreprise',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kSlate900)),
                  ]),
                  const SizedBox(height: 12),
                  Center(
                    child: logoBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              logoBytes,
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: kSlate200,
                                  style: BorderStyle.solid),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 32, color: kSlate500),
                                SizedBox(height: 4),
                                Text('Aucun logo',
                                    style: TextStyle(
                                        color: kSlate500, fontSize: 12)),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.upload_outlined, size: 18),
                        label: Text(logoBytes != null
                            ? 'Changer le logo'
                            : 'Choisir un logo'),
                        onPressed: _pickLogo,
                      ),
                    ),
                    if (logoBytes != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: kRed),
                        tooltip: 'Supprimer le logo',
                        onPressed: _removeLogo,
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  const Text(
                    'Le logo apparaîtra en haut à gauche de vos factures PDF.',
                    style: TextStyle(color: kSlate500, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Enterprise info section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Row(children: [
                    Icon(Icons.business_outlined, size: 18, color: kBlue),
                    SizedBox(width: 6),
                    Text('Informations entreprise',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kSlate900)),
                  ]),
                ),
                const SizedBox(height: 12),
                _field(_nameCtrl, 'Nom de l\'entreprise', Icons.business),
                const SizedBox(height: 12),
                _field(_detailsCtrl, 'Adresse / Détails',
                    Icons.location_on_outlined,
                    maxLines: 3),
                const SizedBox(height: 12),
                _field(_phoneCtrl, 'Téléphone', Icons.phone_outlined,
                    keyboard: TextInputType.phone),
                const SizedBox(height: 12),
                _field(_mfCtrl, 'MF (Matricule Fiscal)', Icons.badge_outlined),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Sauvegarder'),
                    onPressed: _save,
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
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
