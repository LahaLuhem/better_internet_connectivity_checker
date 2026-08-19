part of '../internet_connection.dart';

/// Internal periodic-tick scheduler.
///
/// Owns the [Timer] behind [InternetConnection]'s recurring checks and the loop that fires `onTick`
/// then queues the next tick. The coordinator drives the lifecycle via [start], [stop],
/// [updateInterval], and [dispose]. The scheduler stays dumb about what "checking" means.
///
/// Overlapping `onTick` invocations are deliberately allowed — the package contract
/// (APPENDIX `why-checkOnce-not-single-flighted`) permits parallel probes when an external trigger
/// fires mid-check.
final class _PeriodicScheduler {
  Duration _interval;
  final Future<void> Function() _onTick;
  Timer? _timer;
  var _running = false;
  var _disposed = false;

  new({required this._interval, required this._onTick});

  /// Begins ticking, or resets the rescheduling clock if already running.
  ///
  /// Cancels any pending timer, invokes `onTick` once immediately, then schedules the next tick at
  /// the current interval once that future completes. A no-op after [dispose].
  void start() {
    if (_disposed) return;

    _running = true;
    _cancelTimer();
    unawaited(_runTickAndReschedule());
  }

  /// Cancels any pending tick and suppresses rescheduling until the next [start]. An in-flight `onTick`
  /// still completes, but the running-flag check drops its next-tick scheduling.
  void stop() {
    _running = false;
    _cancelTimer();
  }

  /// Replaces the tick interval, resetting the timer if running.
  ///
  /// On a running scheduler, discards the in-flight rescheduling clock and queues a fresh timer at
  /// the new [interval]. When paused or disposed it's a no-op — the interval takes effect on next [start].
  void updateInterval(Duration interval) {
    _interval = interval;
    if (!_running || _disposed) return;

    _cancelTimer();
    _timer = Timer(_interval, _onTimerFire);
  }

  /// Permanently stops the scheduler. Subsequent [start] is a no-op.
  void dispose() {
    _disposed = true;
    _running = false;
    _cancelTimer();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTimerFire() {
    _timer = null;
    if (!_running || _disposed) return;

    unawaited(_runTickAndReschedule());
  }

  Future<void> _runTickAndReschedule() async {
    await _onTick();
    if (!_running || _disposed) return;

    _timer = Timer(_interval, _onTimerFire);
  }
}
