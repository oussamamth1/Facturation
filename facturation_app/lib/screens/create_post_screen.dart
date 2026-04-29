import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/job_post.dart';
import '../models/worker_profile.dart';
import '../providers/posts_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/cloudinary_service.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final JobPost? existing;
  const CreatePostScreen({super.key, this.existing});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  String? _service;
  bool _saving = false;
  final List<String> _imageUrls = [];
  final List<Uint8List> _imagePreviews = [];
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _service = p.service;
      _descCtrl.text = p.description;
      _timeCtrl.text = p.availableTime;
      _locationCtrl.text = p.location;
      _contactCtrl.text = p.contactInfo;
      _imageUrls.addAll(p.imageUrls);
    }
  }

  Future<void> _pickImage() async {
    if (_imageUrls.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 4 photos')));
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() { _uploadingImage = true; _imagePreviews.add(bytes); });
    try {
      final url = await cloudinaryService.uploadImage(
          bytes, folder: 'posts', filename: 'photo.jpg');
      setState(() => _imageUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur upload: $e')));
        _imagePreviews.removeLast();
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageUrls.removeAt(index);
      if (index < _imagePreviews.length) _imagePreviews.removeAt(index);
    });
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _timeCtrl.dispose();
    _locationCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un type de service')),
      );
      return;
    }
    setState(() => _saving = true);
    final userId = ref.read(currentUserIdProvider)!;
    final settings = ref.read(settingsProvider).value;
    final clientName = settings?.name.isNotEmpty == true
        ? settings!.name
        : ref.read(currentUserProvider)?.email ?? 'Client';

    final post = JobPost(
      id: widget.existing?.id ?? '',
      clientId: userId,
      clientName: clientName,
      service: _service!,
      description: _descCtrl.text.trim(),
      availableTime: _timeCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      contactInfo: _contactCtrl.text.trim(),
      status: widget.existing?.status ?? 'open',
      imageUrls: List.from(_imageUrls),
    );

    final svc = ref.read(postsServiceProvider);
    if (widget.existing == null) {
      await svc.createPost(post);
    } else {
      await svc.updatePost(post);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.existing == null
                ? 'Annonce publiée !'
                : 'Annonce mise à jour')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier l\'annonce' : 'Publier une annonce'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Service chips
            const Text('Type de service *',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WorkerProfile.allServices.map((s) {
                final selected = _service == s;
                return FilterChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (_) => setState(() => _service = s),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description du travail *',
                hintText:
                    'Décrivez le travail à réaliser, l\'état actuel, vos attentes…',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),

            // Available time
            TextFormField(
              controller: _timeCtrl,
              decoration: const InputDecoration(
                labelText: 'Disponibilité *',
                hintText: 'Ex: Lundi matin, semaine prochaine, le 10/05…',
                prefixIcon: Icon(Icons.access_time_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),

            // Location
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Adresse / Lieu *',
                hintText: 'Où se situe le chantier ?',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),

            // Contact info
            TextFormField(
              controller: _contactCtrl,
              decoration: const InputDecoration(
                labelText: 'Contact *',
                hintText: 'Téléphone ou email pour vous contacter',
                prefixIcon: Icon(Icons.contact_phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            // Images
            Row(
              children: [
                const Text('Photos (optionnel)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_imageUrls.length}/4',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Existing / preview thumbnails
                  for (int i = 0; i < _imageUrls.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _imageUrls[i],
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(width: 90, height: 90, color: Colors.grey[200]),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _removeImage(i),
                              child: Container(
                                decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle),
                                padding: const EdgeInsets.all(3),
                                child: const Icon(Icons.close,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Add button
                  if (_imageUrls.length < 4)
                    GestureDetector(
                      onTap: _uploadingImage ? null : _pickImage,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _uploadingImage
                            ? const Center(
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add_photo_alternate_outlined,
                                color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(isEdit ? Icons.save_outlined : Icons.publish_outlined),
              label: Text(isEdit ? 'Enregistrer' : 'Publier'),
            ),
          ],
        ),
      ),
    );
  }
}
