/// Serializes async VideoPlayerController.dispose to avoid overlapping decoders.
class VideoDisposeSerial {
  VideoDisposeSerial._();
  static final VideoDisposeSerial instance = VideoDisposeSerial._();

  Future<void> _chain = Future<void>.value();

  Future<void> run(Future<void> Function() action) {
    final next = _chain.then((_) => action());
    _chain = next.catchError((_) {});
    return next;
  }
}
