import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_event.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

final eventsProvider = StreamProvider.autoDispose<List<CalendarEvent>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('events')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.map(CalendarEvent.fromFirestore).toList());
});

class EventsService {
  final _db = FirebaseFirestore.instance;

  Future<void> save(CalendarEvent event, String userId) async {
    final map = event.toMap(userId);
    if (event.id.isEmpty) {
      final ref = await _db.collection('events').add(map);
      await NotificationService.schedule(
          ref.id, event.title, event.note, event.date, event.time);
    } else {
      await _db
          .collection('events')
          .doc(event.id)
          .set(map, SetOptions(merge: true));
      await NotificationService.cancel(event.id);
      await NotificationService.schedule(
          event.id, event.title, event.note, event.date, event.time);
    }
  }

  Future<void> delete(String id) async {
    await NotificationService.cancel(id);
    await _db.collection('events').doc(id).delete();
  }
}

final eventsServiceProvider = Provider((ref) => EventsService());
