import 'package:cloud_firestore/cloud_firestore.dart';

class JobRequest {
  final String id;
  final String clientId;
  final String clientName;
  final String workerId;
  final String workerName;
  final String service;
  final String description;
  final String location;
  final String status; // 'pending', 'accepted', 'declined', 'completed'
  final DateTime? createdAt;

  const JobRequest({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.workerId,
    required this.workerName,
    this.service = '',
    this.description = '',
    this.location = '',
    this.status = 'pending',
    this.createdAt,
  });

  static String statusLabel(String status) {
    const map = {
      'pending': 'En attente',
      'accepted': 'Acceptée',
      'declined': 'Refusée',
      'completed': 'Terminée',
    };
    return map[status] ?? status;
  }

  factory JobRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JobRequest(
      id: doc.id,
      clientId: d['clientId'] ?? '',
      clientName: d['clientName'] ?? '',
      workerId: d['workerId'] ?? '',
      workerName: d['workerName'] ?? '',
      service: d['service'] ?? '',
      description: d['description'] ?? '',
      location: d['location'] ?? '',
      status: d['status'] ?? 'pending',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'clientName': clientName,
        'workerId': workerId,
        'workerName': workerName,
        'service': service,
        'description': description,
        'location': location,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
