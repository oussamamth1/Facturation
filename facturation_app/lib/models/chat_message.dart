import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      text: d['text'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class ChatConversation {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> unread; // {userId: unreadCount}

  const ChatConversation({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unread = const {},
  });

  String otherName(String myId) {
    final otherId = participants.firstWhere((p) => p != myId, orElse: () => '');
    return participantNames[otherId] ?? 'Inconnu';
  }

  int unreadFor(String myId) => unread[myId] ?? 0;

  factory ChatConversation.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawUnread = d['unread'] as Map<String, dynamic>? ?? {};
    return ChatConversation(
      id: doc.id,
      participants: List<String>.from(d['participants'] ?? []),
      participantNames: Map<String, String>.from(d['participantNames'] ?? {}),
      lastMessage: d['lastMessage'] ?? '',
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
      unread: rawUnread.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  Map<String, dynamic> toMap() => {
        'participants': participants,
        'participantNames': participantNames,
        'lastMessage': lastMessage,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unread': unread,
      };
}
