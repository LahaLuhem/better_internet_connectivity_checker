import 'dart:io';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// Blocks the isolate for a fixed time on every callback, standing in for a slow logger or a metrics
/// push. 50 ms by default, and scenarios can vary it or switch off individual methods.
///
/// Microtask dispatch doesn't save you from this. One isolate means one thread, so sync work in an
/// override parks the event loop for as long as it runs, whichever queue delivered it. The point is
/// to make that cost land in the numbers, as `max_stall_microseconds` and `blocked_duty_ratio`.
///
/// A real `sleep`, not a busy-wait, so CPU stays low while the loop sits there.
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
