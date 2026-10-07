/// Sequential async loaders used after profile document fetch (ordering preserved).
abstract final class ProfileRefreshHelpers {
  ProfileRefreshHelpers._();

  static Future<void> runInOrder(
    List<Future<void> Function()> tasks,
  ) async {
    for (final t in tasks) {
      await t();
    }
  }
}
