import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import 'auth_provider.dart';

final conversationsProvider =
    StreamProvider.autoDispose<List<ChatConversation>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: userId)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ChatConversation.fromFirestore).toList());
});

final messagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, chatId) {
  return FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromFirestore).toList());
});

class ChatService {
  final _db = FirebaseFirestore.instance;

  // Returns existing chat id or creates a new one
  Future<String> getOrCreateChat({
    required String myId,
    required String myName,
    required String otherId,
    required String otherName,
  }) async {
    final existing = await _db
        .collection('chats')
        .where('participants', arrayContains: myId)
        .get();

    for (final doc in existing.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      if (participants.contains(otherId)) return doc.id;
    }

    final ref = await _db.collection('chats').add({
      'participants': [myId, otherId],
      'participantNames': {myId: myName, otherId: otherName},
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    required List<String> participants,
  }) async {
    final batch = _db.batch();
    final chatRef = _db.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    batch.set(msgRef, {
      'senderId': senderId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Build update: lastMessage + increment unread for every OTHER participant
    final update = <String, dynamic>{
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    };
    for (final uid in participants) {
      if (uid != senderId) {
        update['unread.$uid'] = FieldValue.increment(1);
      }
    }
    batch.update(chatRef, update);
    await batch.commit();
  }

  Future<void> markAsRead(String chatId, String userId) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .update({'unread.$userId': 0});
  }
}

// Total unread messages across all conversations for the current user
final totalUnreadProvider = Provider.autoDispose<int>((ref) {
  final myId = ref.watch(currentUserIdProvider) ?? '';
  final convs = ref.watch(conversationsProvider).value ?? [];
  return convs.fold(0, (sum, c) => sum + c.unreadFor(myId));
});

final chatServiceProvider = Provider((ref) => ChatService());
