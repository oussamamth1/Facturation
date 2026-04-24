import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client.dart';
import 'auth_provider.dart';

final clientsProvider = StreamProvider.autoDispose<List<Client>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('clients')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Client.fromFirestore).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });
});

class ClientsService {
  final _db = FirebaseFirestore.instance;

  Future<void> save(Client c, String userId) async {
    final map = c.toMap(userId);
    if (c.id.isEmpty) {
      map['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('clients').add(map);
    } else {
      await _db.collection('clients').doc(c.id).set(map, SetOptions(merge: true));
    }
  }

  Future<void> delete(String id) =>
      _db.collection('clients').doc(id).delete();
}

final clientsServiceProvider = Provider((ref) => ClientsService());
