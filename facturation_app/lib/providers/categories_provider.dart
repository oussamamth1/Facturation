import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import 'auth_provider.dart';

final categoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('categories')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Category.fromFirestore).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });
});

class CategoriesService {
  final _db = FirebaseFirestore.instance;

  Future<String> create(String name, String userId) async {
    final map = {
      'userId': userId,
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final ref = await _db.collection('categories').add(map);
    return ref.id;
  }

  Future<void> rename(String id, String newName) =>
      _db.collection('categories').doc(id).update({
        'name': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> delete(String id) =>
      _db.collection('categories').doc(id).delete();
}

final categoriesServiceProvider = Provider((ref) => CategoriesService());
