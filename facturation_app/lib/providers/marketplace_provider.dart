import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/worker_profile.dart';
import '../models/job_request.dart';
import 'auth_provider.dart';

// All available workers (public listing — no userId filter)
final workersProvider = StreamProvider.autoDispose<List<WorkerProfile>>((ref) {
  return FirebaseFirestore.instance
      .collection('workers')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(WorkerProfile.fromFirestore).toList());
});

// Current user's worker profile (null if not registered as worker)
final myWorkerProfileProvider =
    StreamProvider.autoDispose<WorkerProfile?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('workers')
      .where('userId', isEqualTo: userId)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : WorkerProfile.fromFirestore(s.docs.first));
});

// Job requests where I'm the client or the worker
final jobRequestsProvider = StreamProvider.autoDispose<List<JobRequest>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  // Firestore doesn't support OR queries on different fields directly,
  // so we use two streams and merge them client-side via a combined provider.
  return FirebaseFirestore.instance
      .collection('job_requests')
      .where('clientId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(JobRequest.fromFirestore).toList());
});

final incomingRequestsProvider =
    StreamProvider.autoDispose<List<JobRequest>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('job_requests')
      .where('workerId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(JobRequest.fromFirestore).toList());
});

// Count of pending incoming job requests (for worker badge + dashboard)
final pendingIncomingCountProvider = Provider.autoDispose<int>((ref) {
  final requests = ref.watch(incomingRequestsProvider).value ?? [];
  return requests.where((r) => r.status == 'pending').length;
});

class MarketplaceService {
  final _db = FirebaseFirestore.instance;

  Future<void> saveWorkerProfile(WorkerProfile profile, String userId) async {
    final map = profile.toMap(userId);
    if (profile.id.isEmpty) {
      map['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('workers').add(map);
    } else {
      await _db.collection('workers').doc(profile.id).set(map, SetOptions(merge: true));
    }
  }

  Future<void> deleteWorkerProfile(String id) async {
    await _db.collection('workers').doc(id).delete();
  }

  Future<void> sendJobRequest(JobRequest request) async {
    final map = request.toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('job_requests').add(map);
  }

  Future<void> updateRequestStatus(String id, String status) async {
    await _db.collection('job_requests').doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRequest(String id) async {
    await _db.collection('job_requests').doc(id).delete();
  }
}

final marketplaceServiceProvider = Provider((ref) => MarketplaceService());
