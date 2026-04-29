import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_post.dart';
import 'auth_provider.dart';

// All open posts (public board)
final jobPostsProvider = StreamProvider.autoDispose<List<JobPost>>((ref) {
  return FirebaseFirestore.instance
      .collection('job_posts')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(JobPost.fromFirestore).toList());
});

// Current client's own posts
final myPostsProvider = StreamProvider.autoDispose<List<JobPost>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('job_posts')
      .where('clientId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(JobPost.fromFirestore).toList());
});

// Comments for a specific post
final commentsProvider =
    StreamProvider.autoDispose.family<List<PostComment>, String>((ref, postId) {
  return FirebaseFirestore.instance
      .collection('job_posts')
      .doc(postId)
      .collection('comments')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(PostComment.fromFirestore).toList());
});

class PostsService {
  final _db = FirebaseFirestore.instance;

  Future<void> createPost(JobPost post) async {
    final map = post.toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('job_posts').add(map);
  }

  Future<void> updatePost(JobPost post) async {
    await _db.collection('job_posts').doc(post.id).set(
          post.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> toggleStatus(String postId, String currentStatus) async {
    final newStatus = currentStatus == 'open' ? 'closed' : 'open';
    await _db.collection('job_posts').doc(postId).update({'status': newStatus});
  }

  Future<void> deletePost(String postId) async {
    await _db.collection('job_posts').doc(postId).delete();
  }

  Future<void> addComment({
    required String postId,
    required PostComment comment,
  }) async {
    final batch = _db.batch();
    final commentRef =
        _db.collection('job_posts').doc(postId).collection('comments').doc();
    batch.set(commentRef, comment.toMap());
    batch.update(_db.collection('job_posts').doc(postId),
        {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final batch = _db.batch();
    batch.delete(_db
        .collection('job_posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId));
    batch.update(_db.collection('job_posts').doc(postId),
        {'commentCount': FieldValue.increment(-1)});
    await batch.commit();
  }
}

final postsServiceProvider = Provider((ref) => PostsService());
