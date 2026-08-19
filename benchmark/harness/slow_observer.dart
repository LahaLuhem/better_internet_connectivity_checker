import 'dart:io';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// A [ConnectivityObserver] that synchronously blocks for a configurable duration on every callback —
/// simulating a slow logger, metrics push, or any expensive side-effect a real consumer might wire in.
///
/// Dispatch is microtask-deferred since the event-bus refactor, but a Dart isolate is single-threaded:
/// synchronous work inside an override blocks the event loop for its full duration regardless of which
/// queue dispatched it. This class exists to make that cost observable and measurable — the per-callback
/// delay should reappear as `max_stall_microseconds`, and the delay-to-interval ratio as `blocked_duty_ratio`.
///
/// The blocking is genuine `sleep` (from `dart:io`), not a busy-wait — so CPU usage stays low, but
/// the event loop is paused exactly like a slow synchronous logger would pause it.
///
/// Default: 50 ms delay on every callback. Constructor knobs let scenarios vary the delay or disable
/// per-method delays selectively.
final class SlowObserver extends ConnectivityObserver {
  final Duration _delay;
  final bool _delayOnStatusChange;
  final bool _delayOnCheckCompleted;
  final bool _delayOnTrigger;
  final bool _delayOnConfigChange;
  final bool _delayOnDispose;

  /// Counts of how many times each callback fired. Useful for verifying the scenario exercised the
  /// code paths it was supposed to.
  final callCounts = <String, int>{};

  new({
    this._delay = const Duration(milliseconds: 50),
    this._delayOnStatusChange = true,
    this._delayOnCheckCompleted = true,
    this._delayOnTrigger = true,
    this._delayOnConfigChange = false,
    this._delayOnDispose = false,
  });

  @override
  void onStatusChangeEmitted(InternetStatus? previous, InternetStatus next) {
    _tally('onStatusChangeEmitted');
    if (_delayOnStatusChange) sleep(_delay);
  }

  @override
  void onCheckCompleted(InternetStatus result) {
    _tally('onCheckCompleted');
    if (_delayOnCheckCompleted) sleep(_delay);
  }

  @override
  void onExternalTriggerFired() {
    _tally('onExternalTriggerFired');
    if (_delayOnTrigger) sleep(_delay);
  }

  @override
  void onExternalTriggerError(Object error, StackTrace stackTrace) {
    _tally('onExternalTriggerError');
    if (_delayOnTrigger) sleep(_delay);
  }

  @override
  void onCheckIntervalChanged(Duration previous, Duration next) {
    _tally('onCheckIntervalChanged');
    if (_delayOnConfigChange) sleep(_delay);
  }

  @override
  void onSlowThresholdChanged(Duration? previous, Duration? next) {
    _tally('onSlowThresholdChanged');
    if (_delayOnConfigChange) sleep(_delay);
  }

  @override
  void onDispose() {
    _tally('onDispose');
    if (_delayOnDispose) sleep(_delay);
  }

  void _tally(String method) => callCounts[method] = (callCounts[method] ?? 0) + 1;
}
