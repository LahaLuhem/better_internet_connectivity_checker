/// @docImport 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
library;

import 'dart:async';

/// Measures how long the event loop goes unresponsive, off a 1 ms heartbeat timer.
///
/// Each heartbeat records the gap since the last. A gap past `stallFloor`, 2 ms by default, counts as
/// a stall: the loop was busy with sync work and couldn't service timers. The floor is there because
/// a 1 ms periodic timer runs about 0.2 ms late on most ticks, and counting that would bury the real
/// ones. [maxStall] is the worst single stall, [blockedDutyRatio] is how bad it was overall.
///
/// **Why gaps and not drift.** The retired `TickDriftMeter` measured each heartbeat against a
/// schedule that advanced once per *received* callback. Since the VM coalesces missed ticks, its
/// `maxDrift` was really a running total of lost time scaled by run duration, not a latency: a 5 s
/// run read ~2.75 s of "drift" when no single stall passed ~50 ms. Gaps keep each blocking window
/// separate, so [maxStall] compares across run lengths. `Timer.tick` correction is no help either, it
/// self-adjusts past the coalescing and hides the stall completely.
///
/// ```dart
/// final meter = EventLoopStallMeter()..start();
/// // ... run scenario, possibly with a SlowObserver attached ...
/// meter.stop();
/// print('max stall: ${meter.maxStall.inMilliseconds} ms');
/// print('blocked: ${(meter.blockedDutyRatio * 100).toStringAsFixed(1)} %');
/// ```
final class EventLoopStallMeter {
  final Duration _interval;
  final Duration _stallFloor;
  final _stalls = <Duration>[];
  Timer? _timer;
  Stopwatch? _stopwatch;
  Duration _lastFire = .zero;

  new({
    this._interval = const Duration(milliseconds: 1),
    this._stallFloor = const Duration(milliseconds: 2),
  });

  /// Every stall, in order. Mostly zeros on a healthy loop, with blocking windows as lone spikes.
  List<Duration> get stalls => List.unmodifiable(_stalls);

  /// Longest single continuous stall seen so far. Zero if no samples.
  Duration get maxStall => _stalls.isEmpty ? .zero : _stalls.reduce((a, b) => a > b ? a : b);

  /// Total event-loop time lost to stalls over the measured window.
  Duration get totalBlocked => _stalls.fold(.zero, (a, b) => a + b);

  /// Share of the window spent stalled, `0.0` to `1.0`. Works mid-run, reads zero before [start].
  ///
  /// Sub-floor jitter is left out, so an idle loop reads about 0 rather than the ~15% phantom floor a
  /// raw gap-sum would give you.
  double get blockedDutyRatio {
    final elapsedMicroseconds = _stopwatch?.elapsed.inMicroseconds ?? 0;
    if (elapsedMicroseconds == 0) return 0;

    return totalBlocked.inMicroseconds / elapsedMicroseconds;
  }

  void start() {
    if (_timer != null) throw StateError('EventLoopStallMeter already started');
    _stopwatch = Stopwatch()..start();
    _lastFire = .zero;
    _timer = Timer.periodic(_interval, _onTick);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopwatch?.stop();
  }

  void _onTick(Timer _) {
    final now = _stopwatch!.elapsed;
    final gap = now - _lastFire;
    _lastFire = now;

    // One stall is one oversized gap, because the VM coalesces the missed heartbeats into a single
    // late callback. Sub-floor gaps are timer granularity rather than blocking, and summing that
    // jitter would inflate `blockedDutyRatio` into a big phantom floor, so they record zero.
    _stalls.add(gap > _stallFloor ? gap - _interval : .zero);
  }
}
