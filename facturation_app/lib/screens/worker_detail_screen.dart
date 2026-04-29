import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/worker_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import 'chat_screen.dart';
import 'job_request_screen.dart';

class WorkerDetailScreen extends ConsumerWidget {
  final WorkerProfile worker;

  const WorkerDetailScreen({super.key, required this.worker});

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    final myId = ref.read(currentUserIdProvider)!;
    if (myId == worker.userId) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ceci est votre profil')));
      return;
    }
    final settings = ref.read(settingsProvider).value;
    final myName = settings?.name.isNotEmpty == true
        ? settings!.name
        : ref.read(currentUserProvider)?.email ?? 'Moi';
    final chatId = await ref.read(chatServiceProvider).getOrCreateChat(
          myId: myId,
          myName: myName,
          otherId: worker.userId,
          otherName: worker.name,
        );
    if (context.mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ChatScreen(chatId: chatId, otherName: worker.name)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(currentUserIdProvider) ?? '';
    final isMyProfile = myId == worker.userId;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(worker.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar & name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: worker.photoUrl.isNotEmpty
                      ? NetworkImage(worker.photoUrl)
                      : null,
                  child: worker.photoUrl.isEmpty
                      ? Text(
                          worker.name.isNotEmpty
                              ? worker.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              fontSize: 32,
                              color: colorScheme.onPrimaryContainer),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(worker.name,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                _AvailabilityBadge(available: worker.available),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Services
          _Section(
            title: 'Services',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: worker.services
                  .map((s) => Chip(label: Text(s)))
                  .toList(),
            ),
          ),

          // Location
          if (worker.location.isNotEmpty)
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: worker.location,
            ),

          // Phone
          if (worker.phone.isNotEmpty)
            _InfoRow(
              icon: Icons.phone_outlined,
              label: worker.phone,
              onTap: () => _call(worker.phone),
            ),

          // Description
          if (worker.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(
              title: 'À propos',
              child: Text(worker.description,
                  style: const TextStyle(height: 1.5)),
            ),
          ],

          const SizedBox(height: 32),

          // Actions
          if (!isMyProfile) ...[
            FilledButton.icon(
              onPressed: worker.available
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              JobRequestScreen(worker: worker)))
                  : null,
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Envoyer une demande'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openChat(context, ref),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Contacter'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final bool available;
  const _AvailabilityBadge({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: available
            ? Colors.green.withOpacity(0.15)
            : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle,
              size: 8, color: available ? Colors.green : Colors.grey),
          const SizedBox(width: 4),
          Text(available ? 'Disponible' : 'Indisponible',
              style: TextStyle(
                  fontSize: 12,
                  color: available ? Colors.green : Colors.grey)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 16),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _InfoRow({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      onTap: onTap,
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
    );
  }
}
