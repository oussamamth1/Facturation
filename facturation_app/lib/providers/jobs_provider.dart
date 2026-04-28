import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

final jobsProvider = StreamProvider.autoDispose<List<Job>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('jobs')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Job.fromFirestore).toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      });
});

class JobsService {
  final _db = FirebaseFirestore.instance;

  Future<void> save(Job j, String userId) async {
    final map = j.toMap(userId);
    String id = j.id;
    if (j.id.isEmpty) {
      map['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _db.collection('jobs').add(map);
      id = ref.id;
    } else {
      await _db.collection('jobs').doc(j.id).set(map, SetOptions(merge: true));
      await NotificationService.cancel('job_$id');
    }
    await NotificationService.schedule(
      'job_$id',
      j.client,
      j.service.isNotEmpty ? j.service : 'Travail planifié',
      j.date,
      j.time,
    );
  }

  Future<void> delete(String id) async {
    await NotificationService.cancel('job_$id');
    await _db.collection('jobs').doc(id).delete();
  }
}

final jobsServiceProvider = Provider((ref) => JobsService());
