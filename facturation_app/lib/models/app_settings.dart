import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettings {
  final String name;
  final String details;
  final String phone;
  final String mf;
  final String userId;

  const AppSettings({
    this.name = '',
    this.details = '',
    this.phone = '',
    this.mf = '',
    this.userId = '',
  });

  factory AppSettings.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppSettings(
      name: d['name'] ?? '',
      details: d['details'] ?? '',
      phone: d['phone'] ?? '',
      mf: d['mf'] ?? '',
      userId: d['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'userId': userId,
        'name': name,
        'details': details,
        'phone': phone,
        'mf': mf,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  AppSettings copyWith({
    String? name,
    String? details,
    String? phone,
    String? mf,
  }) =>
      AppSettings(
        name: name ?? this.name,
        details: details ?? this.details,
        phone: phone ?? this.phone,
        mf: mf ?? this.mf,
        userId: userId,
      );
}
