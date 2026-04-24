import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import 'auth_provider.dart';

final settingsProvider = StreamProvider.autoDispose<AppSettings>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('settings')
      .doc('enterprise_$userId')
      .snapshots()
      .map((doc) => doc.exists ? AppSettings.fromFirestore(doc) : const AppSettings());
});

class SettingsService {
  final _db = FirebaseFirestore.instance;

  Future<void> save(AppSettings s, String userId) async {
    await _db.collection('settings').doc('enterprise_$userId').set(
          s.toMap(userId),
          SetOptions(merge: true),
        );
  }
}

final settingsServiceProvider = Provider((ref) => SettingsService());
