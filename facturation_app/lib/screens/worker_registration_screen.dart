import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/worker_profile.dart';
import '../providers/marketplace_provider.dart';
import '../providers/auth_provider.dart';
import '../services/cloudinary_service.dart';

class WorkerRegistrationScreen extends ConsumerStatefulWidget {
  const WorkerRegistrationScreen({super.key});

  @override
  ConsumerState<WorkerRegistrationScreen> createState() =>
      _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState
    extends ConsumerState<WorkerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final Set<String> _selectedServices = {};
  bool _available = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _existingId;
  String _photoUrl = '';
  Uint8List? _photoPreview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  void _loadExisting() {
    final profile = ref.read(myWorkerProfileProvider).value;
    if (profile != null) {
      _existingId = profile.id;
      _nameCtrl.text = profile.name;
      _phoneCtrl.text = profile.phone;
      _descCtrl.text = profile.description;
      _locationCtrl.text = profile.location;
      _selectedServices.addAll(profile.services);
      _available = profile.available;
      _photoUrl = profile.photoUrl;
      setState(() {});
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() { _uploadingPhoto = true; _photoPreview = bytes; });
    try {
      _photoUrl = await cloudinaryService.uploadImage(
          bytes, folder: 'workers', filename: 'profile.jpg');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur upload: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un service')),
      );
      return;
    }
    setState(() => _saving = true);
    final userId = ref.read(currentUserIdProvider)!;
    final service = ref.read(marketplaceServiceProvider);
    final profile = WorkerProfile(
      id: _existingId ?? '',
      userId: userId,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      services: _selectedServices.toList(),
      available: _available,
      photoUrl: _photoUrl,
    );
    await service.saveWorkerProfile(profile, userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil artisan sauvegardé')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    if (_existingId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le profil'),
        content: const Text('Votre profil artisan sera supprimé du marketplace.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(marketplaceServiceProvider).deleteWorkerProfile(_existingId!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingId != null ? 'Mon profil artisan' : 'Devenir artisan'),
        actions: [
          if (_existingId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Créez votre profil pour être trouvé par des clients.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            // Profile photo
            Center(
              child: GestureDetector(
                onTap: _uploadingPhoto ? null : _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: _photoPreview != null
                          ? MemoryImage(_photoPreview!)
                          : (_photoUrl.isNotEmpty
                              ? NetworkImage(_photoUrl) as ImageProvider
                              : null),
                      child: (_photoPreview == null && _photoUrl.isEmpty)
                          ? Icon(Icons.person_outline,
                              size: 40,
                              color: Theme.of(context).colorScheme.onPrimaryContainer)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _uploadingPhoto
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom complet *',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Zone / Ville',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description / Expérience',
                prefixIcon: Icon(Icons.info_outline),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text('Services proposés *',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WorkerProfile.allServices.map((service) {
                final selected = _selectedServices.contains(service);
                return FilterChip(
                  label: Text(service),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedServices.add(service);
                    } else {
                      _selectedServices.remove(service);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Disponible'),
              subtitle: const Text('Visible et disponible pour de nouvelles missions'),
              value: _available,
              onChanged: (v) => setState(() => _available = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enregistrer le profil'),
            ),
          ],
        ),
      ),
    );
  }
}
