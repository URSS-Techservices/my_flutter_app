import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:halo/features/create_post/domain/media_asset.dart';

/// Writes the finished post: one atomic batch for the post document and the
/// author's `postsCount` bump, so a crash between the two writes can't
/// happen. Media entries are written verbatim from [UploadService]'s result
/// maps — same field dialect the feed/profile/search readers and the Cloud
/// Function transcoder already expect; no schema change.
class PostRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createPost({
    required String postId,
    required String userId,
    required List<MediaAsset> media,
    required String caption,
    required String location,
    required List<String> tags,
    required List<String> mentions,
  }) async {
    final mediaList = media
        .map((a) => Map<String, dynamic>.from(a.uploadResult ?? const <String, dynamic>{}))
        .toList();

    final images = mediaList
        .where((m) => m['type'] == 'image')
        .map((m) => (m['url'] ?? '').toString())
        .where((u) => u.isNotEmpty)
        .toList();

    final batch = _firestore.batch();
    final postRef = _firestore.collection('posts').doc(postId);
    batch.set(postRef, {
      'userId': userId,
      'media': mediaList,
      'images': images,
      'caption': caption,
      'location': location,
      'tags': tags,
      'mentions': mentions,
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {'postsCount': FieldValue.increment(1)});

    await batch.commit();
    return postId;
  }
}
