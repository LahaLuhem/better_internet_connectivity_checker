// no-op defaults are the design — subclasses override only the events they care about.
// See class-level dartdoc.
// ignore_for_file: no-empty-block

/// @docImport '../internet_connection.dart';
library;

import 'dart:async';

import '../data/values.dart';
import '../status/internet_status.dart';
import 'events/connectivity_event.dart';
import 'slow_callback_watchdog.dart';

/// Lifecycle observer for [InternetConnection].
///
/// Wires diagnostics, telemetry, or logging into the checker without re-formatting domain events.
/// Subclass it, override only the events you care about, and attach it via the top-level [attachObserver].
/// Unoverridden events cost nothing — a no-op default body, no formatting or allocation, since the domain object is already built.
///
/// Extend, don't implement: `abstract base` lets future minor releases add new lifecycle events
/// (shipping with no-op defaults) without breaking existing subclasses.
///
/// ```dart
/// final class _MyObserver extends ConnectivityObserver {
///   const _MyObserver(this._log);
///   final void Function(String) _log;
///
///   @override
///   void onStatusChangeEmitted(InternetStatus previous, InternetStatus next) =>
///       _log('connectivity: $previous -> $next');
/// }
/// ```
///
/// {@template connectivity_observer_threading}
/// Wired through [attachObserver], callbacks fire from the [ConnectivityEvent] stream, microtask-deferred
/// from the frame that produced the event. The deferral does **not** insulate the event loop from
/// synchronous work in an override: a Dart isolate is single-threaded, so `sleep`, sync IO, or a busy
/// loop blocks every timer, stream, and (in Flutter) frame on the isolate for its full duration.
/// The check scheduler stays on cadence only while per-tick observer work stays below the check interval.
/// Past that, checks are delayed too.
///
/// Keep overrides fast. For an expensive sink, hand the event to async machinery (a buffered `StreamController`, an async logging API)
/// or offload heavy work with `Isolate.run` on copied data. In debug builds, [attachObserver] times
/// each callback and warns once per event type when an override overruns its budget — see its
/// `slowCallbackThreshold`.
/// {@endtemplate}
abstract base class ConnectivityObserver {
  /// Const default constructor — subclasses are encouraged to be const.
  const new();

  // No-op defaults so subclasses override only the events they care about. Excluded from
  // coverage: exercising them needs a do-nothing subclass that adds nothing over `RecordingObserver`.
  // coverage:ignore-start

  /// Called when [InternetConnection.onStatusChange] emits a deduplicated status transition.
  ///
  /// [previous] is null on the first emission of a fresh subscription (the scheduler clears its
  /// memory between subscriber lifetimes, so a resubscription starts null again). This fires only
  /// for emissions consumers actually see, not every check — use [onCheckCompleted] for per-tick visibility.
  void onStatusChangeEmitted(InternetStatus? previous, InternetStatus next) {
    // No-op default; override to observe deduped status transitions.
  }

  /// Called after every internal check completes — periodic ticks and trigger-driven rechecks
  /// alike — whether or not the result changed the emitted status.
  ///
  /// Does **not** fire for [InternetConnection.checkOnce]: that path is caller-driven and the caller
  /// already has the result. High-frequency (once per [InternetConnection.checkInterval] tick plus once per trigger),
  /// so it suits verbose per-tick tracing.
  void onCheckCompleted(InternetStatus result) {
    // No-op default; override for per-tick check tracing.
  }

  /// Called when the `externalRecheckTrigger` stream fires, causing an out-of-band recheck.
  ///
  /// Fires before the resulting check runs; pair with [onCheckCompleted] to time the recheck.
  void onExternalTriggerFired() {
    // No-op default; override to trace external trigger events.
  }

  /// Called when the `externalRecheckTrigger` stream surfaces an error.
  ///
  /// [InternetConnection] swallows the error (the trigger is best-effort and must not disturb the status stream),
  /// so this callback is a consumer's only signal that the trigger failed.
  void onExternalTriggerError(Object error, StackTrace stackTrace) {
    // No-op default; override to forward trigger-stream errors.
  }

  /// Called when [InternetConnection.checkInterval] is assigned.
  ///
  /// Fires even when [previous] equals [next] — the timer is reset on every assignment.
  void onCheckIntervalChanged(Duration previous, Duration next) {
    // No-op default; override to trace interval reconfigurations.
  }

  /// Called when [InternetConnection.slowThreshold] is assigned.
  ///
  /// Either bound may be null (slow classification disabled). Fires even when [previous] equals [next].
  void onSlowThresholdChanged(Duration? previous, Duration? next) {
    // No-op default; override to trace slow-threshold reconfigurations.
  }

  /// Called once when [InternetConnection.dispose] finishes tearing down the timer, trigger subscription,
  /// and status stream. Idempotent: later `dispose` calls do not re-invoke it.
  void onDispose() {
    // No-op default; override to observe checker teardown.
  }
  // coverage:ignore-end
}

/// Bridges a stream of [ConnectivityEvent]s to a [ConnectivityObserver].
///
/// Subscribes [observer] to [events], dispatching each typed event to the matching `onXyz` callback.
/// Returns the [StreamSubscription] to cancel explicitly, or let the source stream close
/// (e.g. [InternetConnection.dispose] closes [InternetConnection.events]) to auto-cancel. Multiple
/// observers can attach to one stream; each call gets an independent broadcast subscription.
///
/// ```dart
/// final connection = InternetConnection(...);
/// final subscription = attachObserver(connection.events, PrintingConnectivityObserver());
/// await subscription.cancel();   // explicit cleanup, OR
/// await connection.dispose();    // implicit — closes events, cancelling the subscription
/// ```
///
/// The dispatch switch is exhaustive over the sealed [ConnectivityEvent] hierarchy, so adding an event
/// without its `onXyz` callback is a compile-time error here rather than a silent no-op.
///
/// In debug builds every callback is timed; the first to overrun [slowCallbackThreshold] logs a one-shot
/// `dart:developer` warning per event type naming the offending override. Synchronous work in a callback
/// blocks the isolate's event loop for its full duration (see the threading notes on [ConnectivityObserver]),
/// so the default budget is one 60 fps frame ([Values.defaultSlowCallbackThreshold]), where jank starts.
/// Release and profile builds strip the watchdog. Dispatch is direct and unmeasured.
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

  // Reassigned inside the assert so the watchdog lives only where asserts run (debug, tests).
  // Release keeps the bare dispatch.
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
