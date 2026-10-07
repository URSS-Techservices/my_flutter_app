import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Measured width/height per carousel index for one post.
class MediaAspectController extends StateNotifier<Map<int, double>> {
  MediaAspectController() : super(const {});

  void setAspect(int index, double aspect) {
    if (aspect <= 0) return;
    final prev = state[index];
    if (prev != null && (prev - aspect).abs() < 0.01) return;
    state = {...state, index: aspect};
  }
}

final mediaAspectProvider = StateNotifierProvider.autoDispose
    .family<MediaAspectController, Map<int, double>, String>((ref, postId) {
  return MediaAspectController();
});

/// Safe to call from image/video listeners — never writes during build.
void reportMediaAspect(
  WidgetRef ref, {
  required bool Function() isMounted,
  required String postId,
  required int index,
  required double aspect,
}) {
  void write() {
    if (!isMounted()) return;
    ref.read(mediaAspectProvider(postId).notifier).setAspect(index, aspect);
  }

  final phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
    write();
    return;
  }
  SchedulerBinding.instance.addPostFrameCallback((_) => write());
}
