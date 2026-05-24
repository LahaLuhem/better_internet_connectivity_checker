part of '../internet_connection.dart';

/// Internal periodic-tick scheduler.
///
/// Owns the [Timer] underlying [InternetConnection]'s recurring checks and
/// the rescheduling loop that fires `onTick` then queues the next tick.
/// The coordinator (the facade class) drives the lifecycle via [start],
/// [stop], [updateInterval], and [dispose]; the scheduler itself is dumb
/// about what "checking" means or when it should be active.
///
/// Overlapping invocations of `onTick` are deliberately not prevented —
/// today's package contract (see APPENDIX `why-checkOnce-not-single-flighted`)
/// allows parallel probes when the external recheck trigger fires during
/// an in-flight scheduled check. The scheduler matches that contract.
final class _PeriodicScheduler {
  Duration _interval;
  final Future<void> Function() _onTick;
  Timer? _timer;
  var _running = false;
  var _disposed = false;

  _PeriodicScheduler({required Duration interval, required Future<void> Function() onTick})
    : _interval = interval,
      _onTick = onTick;

  /// Begins ticking, or resets the rescheduling clock if already running.
  ///
  /// Cancels any pending timer and immediately invokes `onTick` once; after
  /// `onTick`'s returned future completes, schedules the next tick at the
  /// current interval. A no-op after [dispose].
  void start() {
    if (_disposed) return;

    _running = true;
    _cancelTimer();
    unawaited(_runTickAndReschedule());
  }

  /// Cancels any pending tick and prevents future rescheduling until the
  /// next [start]. Any in-flight `onTick` is allowed to complete but its
  /// next-tick scheduling is suppressed by the running-flag check.
  void stop() {
    _running = false;
    _cancelTimer();
  }

  /// Replaces the current tick interval and resets the timer if running.
  ///
  /// When called on a running scheduler, the in-flight rescheduling clock
  /// is discarded and a fresh timer is queued at the new [interval]. A
  /// no-op when paused or disposed (the new interval takes effect on the
  /// next [start]).
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
