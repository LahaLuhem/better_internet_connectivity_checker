part of '../internet_connection.dart';

/// Internal periodic-tick scheduler.
///
/// Owns the [Timer] behind [InternetConnection]'s recurring checks and the loop that fires `onTick`
/// then queues the next tick. The coordinator drives the lifecycle via [start], [stop],
/// [rescheduleAfter], and [dispose]. The scheduler stays dumb about what "checking" means: each
/// delay arrives as `onTick`'s return value, so it never learns why one tick's gap differs from
/// the last's.
///
/// Overlapping `onTick` invocations are deliberately allowed — the package contract
/// (APPENDIX `why-checkOnce-not-single-flighted`) permits parallel probes when an external trigger
/// fires mid-check.
final class _PeriodicScheduler {
  final Future<Duration> Function() _onTick;
  Timer? _timer;
  var _running = false;
  var _disposed = false;

  new({required this._onTick});

  /// Begins ticking, or resets the rescheduling clock if already running.
  ///
  /// Cancels any pending timer, invokes `onTick` once immediately, then schedules the next tick at
  /// the delay that future returns. A no-op after [dispose].
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

  /// Re-queues the pending tick to fire after [delay] instead.
  ///
  /// Discards the in-flight rescheduling clock. A no-op when paused or disposed: the next [start]
  /// ticks immediately anyway, and every later delay comes from `onTick`.
  void rescheduleAfter(Duration delay) {
    if (!_running || _disposed) return;

    _cancelTimer();
    _timer = Timer(delay, _onTimerFire);
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
    final nextDelay = await _onTick();
    if (!_running || _disposed) return;

    _timer = Timer(nextDelay, _onTimerFire);
  }
}
