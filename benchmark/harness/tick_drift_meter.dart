/// @docImport 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
library;

import 'dart:async';

/// Measures event-loop blocking by detecting drift between a 1 ms periodic
/// timer's *expected* and *actual* fire times. Sustained drift = the event
/// loop was busy with synchronous work and couldn't service the timer.
///
/// **Why this is the headline metric.** The `InternetConnection` observer's
/// own dartdoc warns: *"Methods are invoked synchronously on the same zone
/// as the underlying [InternetConnection] event. Heavy work or blocking IO
/// inside an override will stall the checker's scheduling loop."* This
/// class makes that stall observable as a number.
///
/// The post-refactor change (diagnostic events deferred via
/// `scheduleMicrotask`) should cut max drift from "approximately the slow
/// observer's delay" down to "noise floor" (sub-millisecond). The before /
/// after chart for this metric is the PR's main exhibit.
///
/// Usage:
///
/// ```dart
/// final meter = TickDriftMeter()..start();
/// // ... run scenario, possibly with a SlowObserver attached ...
/// meter.stop();
/// print('max drift: ${meter.maxDrift.inMilliseconds} ms');
/// ```
final class TickDriftMeter {
  final Duration _interval;
  final _drifts = <Duration>[];
  Timer? _timer;
  Stopwatch? _stopwatch;
  Duration _expectedNextFire = Duration.zero;

  TickDriftMeter({Duration interval = const Duration(milliseconds: 1)}) : _interval = interval;

  /// All measured drifts in chronological order, as an unmodifiable view.
  List<Duration> get drifts => List.unmodifiable(_drifts);

  /// Largest drift seen so far. Zero if no samples.
  Duration get maxDrift =>
      _drifts.isEmpty ? Duration.zero : _drifts.reduce((a, b) => a > b ? a : b);

  /// Median drift. Zero if no samples.
  Duration get medianDrift {
    if (_drifts.isEmpty) return Duration.zero;
    final sorted = List<Duration>.of(_drifts)..sort();

    return sorted[sorted.length ~/ 2];
  }

  /// p95 drift. Zero if no samples.
  Duration get p95Drift {
    if (_drifts.isEmpty) return Duration.zero;
    final sorted = List<Duration>.of(_drifts)..sort();

    return sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)];
  }

  void start() {
    if (_timer != null) throw StateError('TickDriftMeter already started');
    _stopwatch = Stopwatch()..start();
    _expectedNextFire = _interval;
    _timer = Timer.periodic(_interval, _onTick);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopwatch?.stop();
  }

  void _onTick(Timer _) {
    final actual = _stopwatch!.elapsed;
    final drift = actual - _expectedNextFire;
    // Negative drift (timer fired early) shouldn't happen in practice but
    // we clamp to zero so the metric only captures the "event loop was
    // busy" case.
    _drifts.add(drift.isNegative ? Duration.zero : drift);
    _expectedNextFire += _interval;
  }
}
