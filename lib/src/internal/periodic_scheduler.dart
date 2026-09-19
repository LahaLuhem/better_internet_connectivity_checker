part of '../internet_connection.dart';

/// Owns the [Timer] behind [InternetConnection]'s recurring checks. Deliberately dim about what a
/// check even is: each gap arrives as `onTick`'s return value, so it never learns why one differs
/// from the last.
///
/// Overlapping `onTick` calls are allowed on purpose, since an external trigger firing mid-check is
/// meant to run alongside. See [Appendix](https://github.com/LahaLuhem/better_internet_connectivity_checker/blob/main/APPENDIX.md#why-no-checkonce-coalescing).
final class _PeriodicScheduler({required final Future<Duration> Function() _onTick}) {
  Timer? _timer;
  var _running = false;
  var _disposed = false;

  /// Starts ticking, or restarts the clock if it already is. Ticks once straight away, then waits
  /// whatever `onTick` returned. Does nothing after [dispose].
  void start() {
    if (_disposed) return;

    _running = true;
    _cancelTimer();
    unawaited(_runTickAndReschedule());
  }

  /// Cancels the pending tick and stops rescheduling until the next [start]. An `onTick` already in
  /// flight still finishes, it just doesn't queue another.
  void stop() {
    _running = false;
    _cancelTimer();
  }

  /// Moves the pending tick to fire after [delay] instead. Does nothing while paused or disposed,
  /// since the next [start] ticks immediately anyway.
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
