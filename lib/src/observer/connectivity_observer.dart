// Empty bodies are the design: subclasses override only the events they care about.
// ignore_for_file: no-empty-block

/// @docImport '../internet_connection.dart';
library;

import 'dart:async';

import '../data/values.dart';
import '../schedule/models/schedule_context.dart';
import '../status/internet_status.dart';
import 'events/connectivity_event.dart';
import 'slow_callback_watchdog.dart';

/// Hook for logging or telemetry: subclass it, override the events you want, hand it to
/// [attachObserver]. Anything you don't override is an empty body that costs nothing.
///
/// Extend it, don't implement it. `abstract base` is what lets new events ship in a minor release
/// without breaking your subclass.
///
/// ```dart
/// final class _MyObserver extends ConnectivityObserver {
///   const _MyObserver(this._log);
///   final void Function(String) _log;
///
///   @override
///   void onStatusChangeEmitted(InternetStatus? previous, InternetStatus next) =>
///       _log('connectivity: $previous -> $next');
/// }
/// ```
///
/// {@template connectivity_observer_threading}
/// Callbacks arrive a microtask after the event, which buys you nothing against blocking. One
/// isolate means one thread: a `sleep`, a sync file read or a busy loop inside an override freezes
/// every timer, stream and frame on it. Keep overrides quick, or hand the heavy part to
/// `Isolate.run`. Debug builds warn when one overruns, see [attachObserver]'s `slowCallbackThreshold`.
/// {@endtemplate}
abstract base class ConnectivityObserver {
  /// Creates a [ConnectivityObserver]. Make subclasses const where you can.
  const new();

  // Nothing to cover: exercising these needs a do-nothing subclass that adds nothing over
  // `RecordingObserver`.
  // coverage:ignore-start

  /// A status change reached [InternetConnection.onStatusChange]. Only fires for what subscribers
  /// actually see, so reach for [onCheckCompleted] if you want every tick. [previous] is null on the
  /// first one of a fresh subscription.
  void onStatusChangeEmitted(InternetStatus? previous, InternetStatus next) {}

  /// An internal check finished, whether or not it moved the status. Once per tick plus once per
  /// trigger, so this is the noisy one. Skipped for [InternetConnection.checkOnce], where you're
  /// handed the result anyway.
  void onCheckCompleted(InternetStatus result) {}

  /// The `externalRecheckTrigger` stream fired, just before the recheck it causes. Pair it with
  /// [onCheckCompleted] to time that recheck.
  void onExternalTriggerFired() {}

  /// The `externalRecheckTrigger` stream errored. [InternetConnection] swallows it to keep the status
  /// stream alive, so this is your only sign the trigger broke.
  void onExternalTriggerError(Object error, StackTrace stackTrace) {}

  /// How long until the next check, decided right after the last one. [scheduleContext] is what the
  /// schedule saw, so you can log the failure streak that widened the gap. As noisy as
  /// [onCheckCompleted].
  void onNextCheckScheduled(Duration delay, ScheduleContext scheduleContext) {}

  /// [InternetConnection.checkInterval] was assigned. Fires even when nothing changed, because every
  /// assignment resets the timer.
  void onCheckIntervalChanged(Duration previous, Duration next) {}

  /// [InternetConnection.slowThreshold] was assigned. Either side can be null, meaning slow detection
  /// was off. Fires even when nothing changed.
  void onSlowThresholdChanged(Duration? previous, Duration? next) {}

  /// [InternetConnection.dispose] finished tearing everything down. Fires once, however many times
  /// `dispose` is called.
  void onDispose() {}
  // coverage:ignore-end
}

/// Points [observer] at [events], routing each one to its matching `onXyz` callback.
///
/// Cancel the returned subscription yourself, or let [InternetConnection.dispose] close the stream
/// and do it for you. Attach as many observers to one stream as you like.
///
/// ```dart
/// final subscription = attachObserver(connection.events, PrintingConnectivityObserver());
/// await subscription.cancel(); // or connection.dispose(), which closes events and cancels for you
/// ```
///
/// Debug builds time each callback and warn once per event type when one runs past
/// [slowCallbackThreshold], a 60 fps frame by default. Release and profile builds skip the timing.
StreamSubscription<ConnectivityEvent> attachObserver(
  Stream<ConnectivityEvent> events,
  ConnectivityObserver observer, {
  Duration slowCallbackThreshold = Values.defaultSlowCallbackThreshold,
}) {
  void dispatch(ConnectivityEvent event) => switch (event) {
    StatusEmittedEvent(:final previous, :final next) => observer.onStatusChangeEmitted(
      previous,
      next,
    ),
    CheckCompletedEvent(:final result) => observer.onCheckCompleted(result),
    NextCheckScheduledEvent(:final delay, :final scheduleContext) => observer.onNextCheckScheduled(
      delay,
      scheduleContext,
    ),
    ExternalTriggerFiredEvent() => observer.onExternalTriggerFired(),
    ExternalTriggerErrorEvent(:final error, :final stackTrace) => observer.onExternalTriggerError(
      error,
      stackTrace,
    ),
    CheckIntervalChangedEvent(:final previous, :final next) => observer.onCheckIntervalChanged(
      previous,
      next,
    ),
    SlowThresholdChangedEvent(:final previous, :final next) => observer.onSlowThresholdChanged(
      previous,
      next,
    ),
    DisposedEvent() => observer.onDispose(),
  };

  // Assigned inside the assert, so the watchdog only exists where asserts run. Release gets `dispatch`.
  var handleEvent = dispatch;
  assert(() {
    final watchdog = SlowCallbackWatchdog(
      observerType: observer.runtimeType,
      threshold: slowCallbackThreshold,
    );
    handleEvent = (event) => watchdog.measure(event, () => dispatch(event));

    return true;
  }(), 'watchdog installation always succeeds');

  return events.listen(handleEvent);
}
