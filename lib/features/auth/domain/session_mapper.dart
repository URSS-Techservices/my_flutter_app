import 'package:halo/core/session.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

/// Maps a Firestore user document to [Session]. Login method is ignored.
Session sessionFromUserDoc(String uid, Map<String, dynamic>? data) {
  final raw = data == null
      ? null
      : (data['accountType'] ?? data['category'] ?? data['profileType'])
          ?.toString();
  final kind = tryProfileKindFromAccountType(raw);
  if (kind == null) {
    return Session(status: SessionStatus.needsAccountType, uid: uid);
  }
  return Session(
    status: SessionStatus.ready,
    uid: uid,
    accountType: accountTypeString(kind),
  );
}
