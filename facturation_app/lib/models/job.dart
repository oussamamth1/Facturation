import 'package:cloud_firestore/cloud_firestore.dart';

class Job {
  final String id;
  final String userId;
  final String client;
  final String location;
  final String service;
  final double price;
  final String date;
  final String status;
  final String notes;
  final double amountPaid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Job({
    required this.id,
    required this.userId,
    required this.client,
    this.location = '',
    this.service = '',
    this.price = 0,
    this.date = '',
    this.status = 'Planifié',
    this.notes = '',
    this.amountPaid = 0,
    this.createdAt,
    this.updatedAt,
  });

  double get remaining => price - amountPaid;

  factory Job.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Job(
      id: doc.id,
      userId: d['userId'] ?? '',
      client: d['client'] ?? '',
      location: d['location'] ?? '',
      service: d['service'] ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0,
      date: d['date'] ?? '',
      status: _normalizeStatus(d['status'] ?? 'Planifié'),
      notes: d['notes'] ?? '',
      amountPaid: (d['amountPaid'] as num?)?.toDouble() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static String _normalizeStatus(String s) {
    const map = {
      'planned': 'Planifié',
      'in_progress': 'En cours',
      'done': 'Terminé',
      'cancelled': 'Annulé',
    };
    return map[s] ?? s;
  }

  Map<String, dynamic> toMap(String userId) => {
        'userId': userId,
        'client': client,
        'location': location,
        'service': service,
        'price': price,
        'date': date,
        'status': status,
        'notes': notes,
        'amountPaid': amountPaid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
