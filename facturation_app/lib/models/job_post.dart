import 'package:cloud_firestore/cloud_firestore.dart';

class JobPost {
  final String id;
  final String clientId;
  final String clientName;
  final String service;
  final String description;
  final String availableTime;
  final String location;
  final String contactInfo;
  final String status; // 'open' | 'closed'
  final int commentCount;
  final List<String> imageUrls;
  final DateTime? createdAt;

  const JobPost({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.service = '',
    this.description = '',
    this.availableTime = '',
    this.location = '',
    this.contactInfo = '',
    this.status = 'open',
    this.commentCount = 0,
    this.imageUrls = const [],
    this.createdAt,
  });

  factory JobPost.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JobPost(
      id: doc.id,
      clientId: d['clientId'] ?? '',
      clientName: d['clientName'] ?? '',
      service: d['service'] ?? '',
      description: d['description'] ?? '',
      availableTime: d['availableTime'] ?? '',
      location: d['location'] ?? '',
      contactInfo: d['contactInfo'] ?? '',
      status: d['status'] ?? 'open',
      commentCount: (d['commentCount'] as num?)?.toInt() ?? 0,
      imageUrls: List<String>.from(d['imageUrls'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'clientName': clientName,
        'service': service,
        'description': description,
        'availableTime': availableTime,
        'location': location,
        'contactInfo': contactInfo,
        'status': status,
        'commentCount': commentCount,
        'imageUrls': imageUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class PostComment {
  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime? createdAt;

  const PostComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    this.createdAt,
  });

  factory PostComment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PostComment(
      id: doc.id,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? '',
      text: d['text'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorName': authorName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
