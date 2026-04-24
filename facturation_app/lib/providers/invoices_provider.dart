import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice.dart';
import 'auth_provider.dart';

final invoicesProvider = StreamProvider.autoDispose<List<Invoice>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('invoices')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Invoice.fromFirestore).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });
});

class InvoicesService {
  final _db = FirebaseFirestore.instance;

  Future<String> save(Invoice inv, String userId, int totalCount) async {
    final map = inv.toMap(userId);
    if (inv.id.isEmpty) {
      // Auto-generate invoice number if blank
      final number = inv.number.isEmpty
          ? (totalCount + 1).toString().padLeft(4, '0')
          : inv.number;
      map['number'] = number;
      map['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _db.collection('invoices').add(map);
      return ref.id;
    } else {
      await _db.collection('invoices').doc(inv.id).set(map, SetOptions(merge: true));
      return inv.id;
    }
  }

  Future<void> delete(String id) =>
      _db.collection('invoices').doc(id).delete();
}

final invoicesServiceProvider = Provider((ref) => InvoicesService());
