import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ticks once a minute so "Active 5m ago" labels stay current on screen.
final minuteTickProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});
