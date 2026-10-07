/// Serializes eager (not-yet-visible) video controller *initialization*.
///
/// Hardware decoder allocation on this device class is real, measurable work
/// — several `VideoPlayerController.initialize()` calls landing in the same
/// event-loop tick (e.g. because several video posts were built in the same
/// initial feed page) cause a visible jank spike. This queues those requests
/// so only one is actually allocating a decoder at a time, instead of
/// bounding *how many* run concurrently (that's [VideoDecoderBudget]'s job)
/// without bounding *when* they start.
///
/// Only the eager pre-buffer path uses this — a video that's actually
/// visible right now must never wait behind others in this queue.
class VideoInitSerial {
  VideoInitSerial._();
  static final VideoInitSerial instance = VideoInitSerial._();

  Future<void> _chain = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final result = _chain.then((_) => action());
    _chain = result.then((_) {}).catchError((_) {});
    return result;
  }
}
