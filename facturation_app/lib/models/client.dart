import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String id;
  final String userId;
  final String name;
  final String address;
  final String email;
  final String phone;
  final String mf;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Client({
    required this.id,
    required this.userId,
    required this.name,
    this.address = '',
    this.email = '',
    this.phone = '',
    this.mf = '',
    this.createdAt,
    this.updatedAt,
  });

  factory Client.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Client(
      id: doc.id,
      userId: d['userId'] ?? '',
      name: d['name'] ?? '',
      address: d['address'] ?? '',
      email: d['email'] ?? '',
      phone: d['phone'] ?? '',
      mf: d['mf'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'userId': userId,
        'name': name,
        'address': address,
        'email': email,
        'phone': phone,
        'mf': mf,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Client copyWith({
    String? name,
    String? address,
    String? email,
    String? phone,
    String? mf,
  }) =>
      Client(
        id: id,
        userId: userId,
        name: name ?? this.name,
        address: address ?? this.address,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        mf: mf ?? this.mf,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
