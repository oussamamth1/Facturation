import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerProfile {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String description;
  final List<String> services;
  final bool available;
  final double rating;
  final int ratingCount;
  final String location;
  final String photoUrl;
  final DateTime? createdAt;

  const WorkerProfile({
    required this.id,
    required this.userId,
    required this.name,
    this.phone = '',
    this.description = '',
    this.services = const [],
    this.available = true,
    this.rating = 0,
    this.ratingCount = 0,
    this.location = '',
    this.photoUrl = '',
    this.createdAt,
  });

  static const List<String> allServices = [
    'Plomberie',
    'Électricité',
    'Peinture',
    'Nettoyage',
  ];

  factory WorkerProfile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WorkerProfile(
      id: doc.id,
      userId: d['userId'] ?? '',
      name: d['name'] ?? '',
      phone: d['phone'] ?? '',
      description: d['description'] ?? '',
      services: List<String>.from(d['services'] ?? []),
      available: d['available'] ?? true,
      rating: (d['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (d['ratingCount'] as num?)?.toInt() ?? 0,
      location: d['location'] ?? '',
      photoUrl: d['photoUrl'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'userId': userId,
        'name': name,
        'phone': phone,
        'description': description,
        'services': services,
        'available': available,
        'rating': rating,
        'ratingCount': ratingCount,
        'location': location,
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
