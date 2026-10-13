import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/profile_feature/domain/profile_person.dart';
import 'package:halo/profile_feature/domain/wellness_product.dart';
import 'package:halo/profile_feature/domain/wellness_profile.dart';

/// Wellness page data: services / hours from the user doc, and the guru
/// accounts the owner features.
class WellnessRepository {
  WellnessRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<WellnessProfile?> watchWellness(String wellnessId) {
    return _users.doc(wellnessId).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : WellnessProfile.fromMap(data);
    });
  }

  /// Up to 10 products for the "Popular Products" row.
  Future<List<WellnessProduct>> loadProducts(String wellnessId) async {
    final snap =
        await _users.doc(wellnessId).collection('products').limit(10).get();
    return [
      for (final d in snap.docs)
        if ((d.data()['name'] ?? '').toString().trim().isNotEmpty)
          WellnessProduct.fromMap(d.id, d.data()),
    ];
  }

  /// People for [ids], in the same order. Missing accounts are skipped.
  Future<List<ProfilePerson>> loadPeople(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final found = <String, ProfilePerson>{};
    const chunk = 30;
    final snaps = await Future.wait([
      for (var i = 0; i < ids.length; i += chunk)
        _users
            .where(FieldPath.documentId,
                whereIn: ids.sublist(
                    i, i + chunk > ids.length ? ids.length : i + chunk))
            .get(),
    ]);
    for (final snap in snaps) {
      for (final d in snap.docs) {
        found[d.id] = ProfilePerson.fromMap(d.id, d.data());
      }
    }
    return [
      for (final id in ids)
        if (found[id] != null) found[id]!,
    ];
  }

  Future<void> addFeaturedGuru(String wellnessId, String guruId) =>
      _users.doc(wellnessId).update({
        'featuredGuruIds': FieldValue.arrayUnion([guruId]),
      });

  Future<void> removeFeaturedGuru(String wellnessId, String guruId) =>
      _users.doc(wellnessId).update({
        'featuredGuruIds': FieldValue.arrayRemove([guruId]),
      });
}
