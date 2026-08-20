/// @docImport 'connectivity_observer.dart';
library;

import 'dart:developer' as developer;

import 'events/connectivity_event.dart';

/// Debug-mode timing guard around `attachObserver`'s per-event dispatch.
///
/// A Dart isolate is single-threaded, so synchronous work in a [ConnectivityObserver] override
/// blocks the event loop for its full duration and no dispatch strategy can mask it. The package
/// can't fix a slow override, but it can make one visible in development before it ships as jank.
/// `attachObserver` installs this **only when asserts are enabled** (debug builds, `dart test`);
/// release and profile builds dispatch directly.
///
/// Warns **once per event type** per attachment — the first offence names the override to fix
/// without re-warning at tick rate (a slow `onCheckCompleted` would otherwise log every interval).
///
/// Defaults to [developer.log] under the package's logger name
/// (same channel as `PrintingConnectivityObserver`, `avoid_print`-compliant, DevTools-filterable).
/// `logSink` is injectable as a test seam, since `developer.log` has none.
final class SlowCallbackWatchdog({
  /// Names the offending subclass in the warning.
  required final Type _observerType,

  /// The per-callback budget.
  required final Duration _threshold,

  /// Overrides the [developer.log] default (a test seam, not a consumer knob).
  void Function(String message)? logSink,
}) {
  /// `package:logging`'s `Level.WARNING` — a performance smell, not an error, so below the
  /// trigger-error records' severity.
  static const _warningLevel = 900;

  static const _loggerName = 'better_internet_connectivity_checker';

  final void Function(String message) _logSink = logSink ?? _logToDeveloper;
  final _warnedEventTypes = <Type>{};

  /// Creates a watchdog for one observer attachment.
  this;

  /// Runs [dispatch] for [event], timing it against the threshold.
  ///
  /// Only the callback is timed — stream delivery sits outside the stopwatch — so the reported
  /// duration is attributable to the override alone.
  void measure(ConnectivityEvent event, void Function() dispatch) {
    final stopwatch = Stopwatch()..start();
    dispatch();
    stopwatch.stop();

    if (stopwatch.elapsed <= _threshold) return;
    if (!_warnedEventTypes.add(event.runtimeType)) return;

    _logSink(
      '$_observerType.${_callbackNameFor(event)} took '
      '${stopwatch.elapsedMilliseconds} ms (budget: ${_threshold.inMilliseconds} ms). '
      "Synchronous work in an observer callback blocks this isolate's event "
      'loop for its full duration — keep overrides fast, or offload heavy '
      'work via async APIs or Isolate.run. This warning fires once per event '
      'type and only in debug mode.',
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
