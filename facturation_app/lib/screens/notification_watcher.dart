import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/role_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/posts_provider.dart';
import '../services/push_notification_service.dart';

class NotificationWatcher extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationWatcher({super.key, required this.child});

  @override
  ConsumerState<NotificationWatcher> createState() =>
      _NotificationWatcherState();
}

class _NotificationWatcherState extends ConsumerState<NotificationWatcher> {
  // ── Initial-load guards (skip notifications for existing data on app start)
  bool _convsReady = false;
  bool _requestsReady = false;
  bool _myRequestsReady = false;
  bool _postsReady = false;

  // ── Snapshot tracking
  final Map<String, String> _lastMsg = {}; // chatId → lastMessage
  final Set<String> _knownRequestIds = {};
  final Map<String, String> _requestStatuses = {}; // requestId → status
  final Map<String, int> _postComments = {}; // postId → commentCount

  @override
  void initState() {
    super.initState();
    PushNotificationService.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(currentUserIdProvider) ?? '';
    final role = ref.watch(userRoleProvider).value ?? 'worker';

    // ── 1. New chat messages ───────────────────────────────────────────────
    ref.listen(conversationsProvider, (_, next) {
      final convs = next.value ?? [];
      if (!_convsReady) {
        _convsReady = true;
        for (final c in convs) _lastMsg[c.id] = c.lastMessage;
        return;
      }
      for (final c in convs) {
        final prev = _lastMsg[c.id];
        if (prev != null &&
            c.lastMessage.isNotEmpty &&
            c.lastMessage != prev &&
            c.unreadFor(myId) > 0) {
          PushNotificationService.showMessage(
            title: c.otherName(myId),
            body: c.lastMessage,
          );
        }
        _lastMsg[c.id] = c.lastMessage;
      }
    });

    // ── 2. New job requests (workers) ──────────────────────────────────────
    ref.listen(incomingRequestsProvider, (_, next) {
      final requests = next.value ?? [];
      if (!_requestsReady) {
        _requestsReady = true;
        for (final r in requests) _knownRequestIds.add(r.id);
        return;
      }
      if (role != 'worker') return;
      for (final r in requests) {
        if (!_knownRequestIds.contains(r.id) && r.status == 'pending') {
          PushNotificationService.showRequest(
            title: 'Nouvelle demande de travail',
            body: '${r.clientName} — ${r.service}',
          );
        }
        _knownRequestIds.add(r.id);
      }
    });

    // ── 3. Request status changes (clients) ───────────────────────────────
    ref.listen(jobRequestsProvider, (_, next) {
      final requests = next.value ?? [];
      if (!_myRequestsReady) {
        _myRequestsReady = true;
        for (final r in requests) _requestStatuses[r.id] = r.status;
        return;
      }
      if (role != 'client') return;
      for (final r in requests) {
        final prev = _requestStatuses[r.id];
        if (prev == 'pending' && r.status == 'accepted') {
          PushNotificationService.showStatusUpdate(
            title: 'Demande acceptée ✓',
            body: '${r.workerName} a accepté votre demande — ${r.service}',
          );
        } else if (prev == 'pending' && r.status == 'declined') {
          PushNotificationService.showStatusUpdate(
            title: 'Demande refusée',
            body: '${r.workerName} a refusé votre demande — ${r.service}',
          );
        }
        _requestStatuses[r.id] = r.status;
      }
    });

    // ── 4. New comments on owned posts (clients) ──────────────────────────
    ref.listen(myPostsProvider, (_, next) {
      final posts = next.value ?? [];
      if (!_postsReady) {
        _postsReady = true;
        for (final p in posts) _postComments[p.id] = p.commentCount;
        return;
      }
      if (role != 'client') return;
      for (final p in posts) {
        final prev = _postComments[p.id] ?? 0;
        if (p.commentCount > prev) {
          final diff = p.commentCount - prev;
          PushNotificationService.showComment(
            title: diff == 1
                ? 'Nouveau commentaire'
                : '$diff nouveaux commentaires',
            body: 'Sur votre annonce : ${p.service}',
          );
        }
        _postComments[p.id] = p.commentCount;
      }
    });

    return widget.child;
  }
}
