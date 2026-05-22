import 'dart:io';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// A [ConnectivityObserver] that synchronously blocks for a configurable
/// duration on every callback — simulating a slow logger, metrics push, or
/// any expensive side-effect a real consumer might wire in.
///
/// Pre-refactor, [ConnectivityObserver] callbacks fire **synchronously on
/// the same zone as the underlying `InternetConnection` event** (per the
/// dartdoc on [ConnectivityObserver]). A slow observer therefore stalls the
/// scheduler's tick loop — this class exists to make that latent bug
/// observable and measurable.
///
/// The blocking is genuine `sleep` (from `dart:io`), not a busy-wait — so
/// CPU usage stays low, but the event loop is paused exactly like a slow
/// synchronous logger would pause it.
///
/// Default: 50 ms delay on every callback. Constructor knobs let scenarios
/// vary the delay or disable per-method delays selectively.
final class SlowObserver extends ConnectivityObserver {
  final Duration _delay;
  final bool _delayOnStatusChange;
  final bool _delayOnCheckCompleted;
  final bool _delayOnTrigger;
  final bool _delayOnConfigChange;
  final bool _delayOnDispose;

  /// Counts of how many times each callback fired. Useful for verifying the
  /// scenario exercised the code paths it was supposed to.
  final callCounts = <String, int>{};

  SlowObserver({
    Duration delay = const Duration(milliseconds: 50),
    bool delayOnStatusChange = true,
    bool delayOnCheckCompleted = true,
    bool delayOnTrigger = true,
    bool delayOnConfigChange = false,
    bool delayOnDispose = false,
  }) : _delay = delay,
       _delayOnStatusChange = delayOnStatusChange,
       _delayOnCheckCompleted = delayOnCheckCompleted,
       _delayOnTrigger = delayOnTrigger,
       _delayOnConfigChange = delayOnConfigChange,
       _delayOnDispose = delayOnDispose;

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
