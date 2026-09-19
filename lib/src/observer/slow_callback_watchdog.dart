/// @docImport 'connectivity_observer.dart';
library;

import 'dart:developer' as developer;

import 'events/connectivity_event.dart';

/// Times `attachObserver`'s dispatch where asserts run, so a slow [ConnectivityObserver] override
/// turns up in development instead of shipping as jank.
///
/// Warns once per event type per attachment. A slow `onCheckCompleted` would otherwise log on every
/// tick.
final class SlowCallbackWatchdog({
  /// Names the offending subclass in the warning.
  required final Type _observerType,

  /// The per-callback budget.
  required final Duration _threshold,

  /// Test seam, because [developer.log] has none. Defaults to [developer.log].
  void Function(String message)? logSink,
}) {
  /// `package:logging`'s `Level.WARNING`. A slow callback is a smell, not an error.
  static const _warningLevel = 900;

  static const _loggerName = 'better_internet_connectivity_checker';

  final void Function(String message) _logSink = logSink ?? _logToDeveloper;
  final _warnedEventTypes = <Type>{};

  /// Creates a watchdog for one observer attachment.
  this;

  /// Runs [dispatch] for [event] with a stopwatch on it. Only the callback is timed, not stream
  /// delivery, so the number belongs to the override alone.
  void measure(ConnectivityEvent event, void Function() dispatch) {
    final stopwatch = Stopwatch()..start();
    dispatch();
    stopwatch.stop();

    if (stopwatch.elapsed <= _threshold) return;
    if (!_warnedEventTypes.add(event.runtimeType)) return;

    _logSink(
      '$_observerType.${_callbackNameFor(event)} took '
      '${stopwatch.elapsedMilliseconds} ms (budget: ${_threshold.inMilliseconds} ms). '
      "Sync work in an observer callback blocks this isolate's event loop for "
      'as long as it runs, so keep overrides quick or hand the heavy part to '
      'an async API or Isolate.run. Fires once per event type, debug only.',
    );
  }

  static void _logToDeveloper(String message) =>
      developer.log(message, name: _loggerName, level: _warningLevel);

  static String _callbackNameFor(ConnectivityEvent event) => switch (event) {
    StatusEmittedEvent() => 'onStatusChangeEmitted',
    CheckCompletedEvent() => 'onCheckCompleted',
    NextCheckScheduledEvent() => 'onNextCheckScheduled',
    ExternalTriggerFiredEvent() => 'onExternalTriggerFired',
    ExternalTriggerErrorEvent() => 'onExternalTriggerError',
    CheckIntervalChangedEvent() => 'onCheckIntervalChanged',
    SlowThresholdChangedEvent() => 'onSlowThresholdChanged',
    DisposedEvent() => 'onDispose',
  };
}
