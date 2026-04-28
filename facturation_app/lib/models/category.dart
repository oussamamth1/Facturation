import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String userId;
  final String name;
  final DateTime? createdAt;

  const Category({
    required this.id,
    required this.userId,
    required this.name,
    this.createdAt,
  });

  factory Category.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      userId: d['userId'] ?? '',
      name: d['name'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'userId': userId,
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
