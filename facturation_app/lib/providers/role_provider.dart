import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

// null = not yet chosen, 'client' | 'worker'
final userRoleProvider = StreamProvider.autoDispose<String?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;
        final data = doc.data() as Map<String, dynamic>?;
        return data?['role'] as String?;
      });
});

class RoleService {
  final _db = FirebaseFirestore.instance;

  Future<void> setRole(String userId, String role) async {
    await _db.collection('users').doc(userId).set({
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final roleServiceProvider = Provider((ref) => RoleService());
