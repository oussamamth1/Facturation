import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../chat_screen.dart';

class ChatListTab extends ConsumerWidget {
  const ChatListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(currentUserIdProvider) ?? '';
    final conversations = ref.watch(conversationsProvider);

    return conversations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.3)),
                const SizedBox(height: 12),
                const Text('Aucune conversation',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                const Text(
                  'Contactez un artisan depuis le Marketplace',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72),
          itemBuilder: (_, i) {
            final conv = list[i];
            final otherName = conv.otherName(myId);
            final time = conv.lastMessageAt != null
                ? _formatTime(conv.lastMessageAt!)
                : '';
            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  otherName.isNotEmpty
                      ? otherName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer),
                ),
              ),
              title: Text(otherName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                conv.lastMessage.isNotEmpty
                    ? conv.lastMessage
                    : 'Nouvelle conversation',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: Text(time,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChatScreen(
                        chatId: conv.id, otherName: otherName)),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return DateFormat('HH:mm').format(dt);
    } else if (now.difference(dt).inDays < 7) {
      return DateFormat('EEE', 'fr').format(dt);
    } else {
      return DateFormat('dd/MM').format(dt);
    }
  }
}
