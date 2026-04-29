import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_post.dart';
import '../providers/posts_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/marketplace_provider.dart';
import 'create_post_screen.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final JobPost post;
  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _sending = true);

    final workerProfile = ref.read(myWorkerProfileProvider).value;
    final authorName = workerProfile?.name.isNotEmpty == true
        ? workerProfile!.name
        : ref.read(currentUserProvider)?.email ?? 'Artisan';

    try {
      await ref.read(postsServiceProvider).addComment(
            postId: widget.post.id,
            comment: PostComment(
              id: '',
              authorId: userId,
              authorName: authorName,
              text: text,
            ),
          );
      _commentCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _sending = false);
  }

  void _showFullImage(BuildContext context, List<String> urls, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white)),
          body: PageView.builder(
            controller: PageController(initialPage: index),
            itemCount: urls.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: Image.network(urls[i], fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _callContact() async {
    final info = widget.post.contactInfo;
    Uri? uri;
    if (info.contains('@')) {
      uri = Uri.parse('mailto:$info');
    } else {
      uri = Uri.parse('tel:$info');
    }
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(currentUserIdProvider) ?? '';
    final isOwner = widget.post.clientId == myId;
    final comments = ref.watch(commentsProvider(widget.post.id));
    final colorScheme = Theme.of(context).colorScheme;
    final isOpen = widget.post.status == 'open';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Annonce'),
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        CreatePostScreen(existing: widget.post)),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'toggle') {
                  await ref
                      .read(postsServiceProvider)
                      .toggleStatus(widget.post.id, widget.post.status);
                  if (mounted) Navigator.pop(context);
                } else if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Supprimer l\'annonce'),
                      content: const Text(
                          'Cette annonce et ses commentaires seront supprimés.'),
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
                    await ref
                        .read(postsServiceProvider)
                        .deletePost(widget.post.id);
                    if (mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(isOpen ? 'Marquer comme clôturée' : 'Rouvrir'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Status badge
                Row(
                  children: [
                    _StatusBadge(open: isOpen),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(widget.post.service),
                      backgroundColor: colorScheme.primaryContainer,
                      labelStyle:
                          TextStyle(color: colorScheme.onPrimaryContainer),
                      padding: EdgeInsets.zero,
                    ),
                    const Spacer(),
                    if (widget.post.createdAt != null)
                      Text(
                        DateFormat('dd/MM/yyyy').format(widget.post.createdAt!),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Client name
                Text(widget.post.clientName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Description
                Text(widget.post.description,
                    style: const TextStyle(fontSize: 15, height: 1.5)),
                const SizedBox(height: 16),

                // Info rows
                _InfoTile(
                    icon: Icons.access_time_outlined,
                    label: 'Disponibilité',
                    value: widget.post.availableTime),
                _InfoTile(
                    icon: Icons.location_on_outlined,
                    label: 'Lieu',
                    value: widget.post.location),
                _InfoTile(
                    icon: Icons.contact_phone_outlined,
                    label: 'Contact',
                    value: widget.post.contactInfo,
                    onTap: _callContact),

                // Images
                if (widget.post.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.post.imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _showFullImage(context, widget.post.imageUrls, i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            widget.post.imageUrls[i],
                            height: 200,
                            width: 260,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) => progress == null
                                ? child
                                : Container(
                                    width: 260,
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Commentaires (${widget.post.commentCount})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary),
                  ),
                ),

                // Comments
                comments.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Erreur: $e')),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Aucun commentaire pour le moment.',
                            style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return Column(
                      children: list.map((c) => _CommentTile(
                            comment: c,
                            isOwner: c.authorId == myId,
                            postId: widget.post.id,
                          )).toList(),
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),

          _CommentInput(
              ctrl: _commentCtrl,
              sending: _sending,
              enabled: isOpen,
              onSend: _sendComment,
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool open;
  const _StatusBadge({required this.open});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (open ? Colors.green : Colors.grey).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle,
              size: 8, color: open ? Colors.green : Colors.grey),
          const SizedBox(width: 4),
          Text(open ? 'Ouverte' : 'Clôturée',
              style: TextStyle(
                  fontSize: 12,
                  color: open ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
      title: Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
      subtitle: Text(value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
      trailing: onTap != null
          ? const Icon(Icons.open_in_new, size: 16, color: Colors.grey)
          : null,
    );
  }
}

class _CommentTile extends ConsumerWidget {
  final PostComment comment;
  final bool isOwner;
  final String postId;

  const _CommentTile(
      {required this.comment,
      required this.isOwner,
      required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = comment.createdAt != null
        ? DateFormat('dd/MM HH:mm').format(comment.createdAt!)
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              comment.authorName.isNotEmpty
                  ? comment.authorName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(comment.authorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      Text(time,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      if (isOwner) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => ref
                              .read(postsServiceProvider)
                              .deleteComment(
                                  postId: postId, commentId: comment.id),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(comment.text, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  const _CommentInput({
    required this.ctrl,
    required this.sending,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                enabled: enabled,
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'Laisser un commentaire…'
                      : 'Annonce clôturée',
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: enabled ? (_) => onSend() : null,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 3,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: (sending || !enabled) ? null : onSend,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
