/// @docImport 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
library;

import 'dart:async';

/// Measures continuous event-loop stalls via a 1 ms periodic heartbeat timer.
///
/// Each heartbeat records the gap since the last one; a gap past `stallFloor` (default 2 ms) is a
/// **stall** — a window where the loop was busy with synchronous work and couldn't service timers.
/// The floor discards sub-tick jitter: a 1 ms periodic timer runs ~0.2 ms late on most ticks, and
/// counting that as blocking would swamp real stalls. Two aggregates matter:
///
/// * [maxStall] — the worst *single continuous* stall. For a blocking observer it converges on the
///   per-callback blocking time (~50 ms for the benchmark `SlowObserver`), independent of run length.
/// * [blockedDutyRatio] — the share of the window spent in real stalls: the "how bad overall" number.
///   Multiply by wall-clock to recover total lost time ([totalBlocked]).
///
/// **Why gap-based.** The retired `TickDriftMeter` compared each heartbeat against an expected-fire
/// schedule that advanced one interval per *received* callback. Because the VM coalesces missed periodic
/// ticks, that turned `maxDrift` into a run-duration-scaled *integral* of lost time, not a latency —
/// a 5 s `slow_observer` run read ~2.75 s "drift" though no single stall passed ~50 ms.
/// Gap-based stalls keep each blocking window separate, so `maxStall` is comparable across run lengths.
/// (Issue #6 grew out of misreading the old metric.) `Timer.tick` correction is no fix either: it
/// self-adjusts past coalesced periods and hides the stall entirely.
///
/// Usage:
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

  /// All measured stalls in chronological order, as an unmodifiable view. Mostly zeros on a healthy
  /// loop. Blocking windows show up as isolated spikes (one per coalesced heartbeat).
  List<Duration> get stalls => List.unmodifiable(_stalls);

  /// Longest single continuous stall seen so far. Zero if no samples.
  Duration get maxStall => _stalls.isEmpty ? .zero : _stalls.reduce((a, b) => a > b ? a : b);

  /// Total event-loop time lost to stalls over the measured window.
  Duration get totalBlocked => _stalls.fold(.zero, (a, b) => a + b);

  /// Share of the measured window spent in real stalls, in `0.0 .. 1.0`.
  ///
  /// Denominator is the stopwatch's elapsed time, so it's meaningful mid-run and after [stop]
  /// (zero before [start]). Sub-floor timer jitter is excluded (see the `stallFloor` constructor arg),
  /// so an idle loop reads ~0 rather than the ~15 % phantom floor a raw gap-sum would show.
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

    // A real stall shows up as one oversized gap (the VM coalesces the missed heartbeats into a single late callback).
    // The recorded stall is the excess over the ideal interval. Gaps within [_stallFloor] are timer
    // granularity, not blocking — a 1 ms periodic timer runs ~0.2 ms late on most ticks, and summing
    // that jitter would inflate [blockedDutyRatio] into a large phantom floor — so sub-floor gaps record zero.
    _stalls.add(gap > _stallFloor ? gap - _interval : .zero);
  }
}
