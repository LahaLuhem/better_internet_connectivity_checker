// no-op defaults are the design — subclasses override only the events they care about.
// See class-level dartdoc.
// ignore_for_file: no-empty-block

/// @docImport '../internet_connection.dart';
library;

import 'dart:async';

import '../status/internet_status.dart';
import 'events/connectivity_event.dart';

/// Lifecycle observer for [InternetConnection].
///
/// Exists so consumers can wire diagnostics, telemetry, or logging into the checker
/// without re-formatting domain events themselves. The default implementation provided by
/// [InternetConnection] is silent (no events surfaced); pass a custom subclass via the
/// constructor's `observer` parameter to opt in.
///
/// Designed for **selective verbosity by partial override**. Every method has a no-op default body,
/// so a subclass overrides only the events it cares about. Events the consumer leaves alone cost
/// essentially nothing — no string formatting, no allocation — because the rich domain object
/// passed in is already constructed by the package itself.
///
/// Extend rather than implement: this class is `abstract base`, which preserves the option to add
/// new lifecycle events in future minor releases without breaking existing subclasses
/// (new methods ship with no-op defaults).
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
/// When wired through [attachObserver], methods are dispatched from the
/// underlying [ConnectivityEvent] stream — microtask-deferred from the
/// frame that produced the event. The microtask boundary moves dispatch
/// to a separate execution slot but does **not** insulate the scheduler
/// from synchronous blocking work performed inside an override.
/// Synchronous IO, `sleep`, busy loops, or any other event-loop-blocking
/// work in the override will still stall the underlying check scheduler
/// — the doc warning is preserved, not removed. Prefer async work
/// (return-a-Future operations) for any expensive sink so the scheduler
/// stays on cadence.
/// {@endtemplate}
abstract base class ConnectivityObserver {
  /// Const default constructor — subclasses are encouraged to be const.
  const ConnectivityObserver();

  /// Called when [InternetConnection.onStatusChange] emits a deduplicated
  /// status transition.
  ///
  /// [previous] is null on the very first emission for a fresh subscription
  /// (or after every listener cancels and a new one resubscribes — the
  /// scheduler clears its memory between subscriber lifetimes). Subsequent
  /// calls carry the prior emitted status.
  ///
  /// Emissions are deduped on status *kind* (see
  /// [InternetConnection.onStatusChange]); this callback fires only for the
  /// emissions consumers actually see, not for every scheduled check. Use
  /// [onCheckCompleted] for per-tick visibility.
  void onStatusChangeEmitted(InternetStatus? previous, InternetStatus next) {
    // No-op default; override to observe deduped status transitions.
  }

  /// Called after every internal check completes — both periodic
  /// timer ticks and external-trigger-driven rechecks — regardless of
  /// whether the result changed the emitted status.
  ///
  /// Does **not** fire for [InternetConnection.checkOnce]: that path is
  /// caller-driven and the caller already has the result.
  ///
  /// Useful for verbose tracing — typical "is the probe still running, what
  /// is it seeing" diagnostics. High-frequency: fires once per
  /// [InternetConnection.checkInterval] tick plus once per external
  /// trigger.
  void onCheckCompleted(InternetStatus result) {
    // No-op default; override for per-tick check tracing.
  }

  /// Called when the `externalRecheckTrigger` stream supplied to
  /// [InternetConnection] emits an event, causing an out-of-band recheck.
  ///
  /// Fires before the resulting check runs; pair with [onCheckCompleted] to time the recheck.
  void onExternalTriggerFired() {
    // No-op default; override to trace external trigger events.
  }

  /// Called when the `externalRecheckTrigger` stream surfaces an error.
  ///
  /// The error is swallowed by [InternetConnection] — the trigger is best-effort and its errors
  /// must not propagate to the status stream's listeners — so this callback is the only signal
  /// a consumer gets that the trigger has failed.
  void onExternalTriggerError(Object error, StackTrace stackTrace) {
    // No-op default; override to forward trigger-stream errors.
  }

  /// Called when [InternetConnection.checkInterval] is assigned.
  ///
  /// [previous] is the interval that was in effect before the
  /// assignment; [next] is the new interval. Fires even when [previous]
  /// equals [next] — the underlying timer is reset on every assignment.
  void onCheckIntervalChanged(Duration previous, Duration next) {
    // No-op default; override to trace interval reconfigurations.
  }

  /// Called when [InternetConnection.slowThreshold] is assigned.
  ///
  /// [previous] is the threshold that was in effect before the
  /// assignment; [next] is the new threshold. Either may be null (slow
  /// classification disabled). Fires even when [previous] equals [next].
  void onSlowThresholdChanged(Duration? previous, Duration? next) {
    // No-op default; override to trace slow-threshold reconfigurations.
  }

  /// Called once when [InternetConnection.dispose] finishes tearing down the timer, trigger subscription, and status stream.
  ///
  /// Subsequent calls to `dispose` are idempotent and do not re-invoke this callback.
  void onDispose() {
    // No-op default; override to observe checker teardown.
  }
}

/// Bridges a stream of [ConnectivityEvent]s to a [ConnectivityObserver].
///
/// Subscribes [observer] to [events] and dispatches each typed event to the
/// matching `onXyz` callback. Returns the underlying [StreamSubscription] so
/// the caller can cancel it explicitly — or rely on the source stream
/// closing (e.g. [InternetConnection.dispose] closes
/// [InternetConnection.events]) to auto-cancel.
///
/// ```dart
/// final connection = InternetConnection(...);
/// final subscription = attachObserver(
///   connection.events,
///   PrintingConnectivityObserver(),
/// );
/// // Either: explicit cleanup
/// await subscription.cancel();
/// // Or: implicit cleanup via dispose
/// await connection.dispose();
/// ```
///
/// Multiple observers may be attached to the same [events] stream — each
/// call to [attachObserver] creates an independent broadcast subscription
/// that receives every event.
///
/// The dispatch switch is exhaustive against the sealed
/// [ConnectivityEvent] hierarchy: adding a new event class without a new
/// `onXyz` callback on [ConnectivityObserver] is a compile-time error
/// here, which intentionally surfaces the change at refactor time rather
/// than letting it silently no-op.
StreamSubscription<ConnectivityEvent> attachObserver(
  Stream<ConnectivityEvent> events,
  ConnectivityObserver observer,
) => events.listen((event) {
  switch (event) {
    case StatusEmittedEvent(:final previous, :final next):
      observer.onStatusChangeEmitted(previous, next);
    case CheckCompletedEvent(:final result):
      observer.onCheckCompleted(result);
    case ExternalTriggerFiredEvent():
      observer.onExternalTriggerFired();
    case ExternalTriggerErrorEvent(:final error, :final stackTrace):
      observer.onExternalTriggerError(error, stackTrace);
    case CheckIntervalChangedEvent(:final previous, :final next):
      observer.onCheckIntervalChanged(previous, next);
    case SlowThresholdChangedEvent(:final previous, :final next):
      observer.onSlowThresholdChanged(previous, next);
    case DisposedEvent():
      observer.onDispose();
  }
});
