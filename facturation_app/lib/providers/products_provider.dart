import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import 'auth_provider.dart';

final productsProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('products')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Product.fromFirestore).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });
});

class ProductsService {
  final _db = FirebaseFirestore.instance;

  Future<void> save(Product p, String userId) async {
    final map = p.toMap(userId);
    if (p.id.isEmpty) {
      map['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('products').add(map);
    } else {
      await _db.collection('products').doc(p.id).set(map, SetOptions(merge: true));
    }
  }

  Future<void> delete(String id) =>
      _db.collection('products').doc(id).delete();
}

final productsServiceProvider = Provider((ref) => ProductsService());
