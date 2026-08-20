import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// A [ConnectivityObserver] that records every event it receives.
///
/// Lives under `test/support/` so production code stays free of test
/// scaffolding. Use it to assert that [InternetConnection] fires the
/// expected lifecycle callbacks in the expected order with the expected
/// payloads.
final class RecordingObserver extends ConnectivityObserver {
  /// Creates a [RecordingObserver] starting with an empty event log.
  new();

  /// Every event the observer has received, in order.
  final List<RecordedEvent> events = [];

  @override
  void onStatusChangeEmitted(InternetStatus? previous, InternetStatus next) =>
      events.add(StatusChangeEmitted(previous: previous, next: next));

  @override
  void onCheckCompleted(InternetStatus result) => events.add(CheckCompleted(result: result));

  @override
  void onNextCheckScheduled(Duration delay, ScheduleContext scheduleContext) =>
      events.add(NextCheckScheduled(delay: delay, scheduleContext: scheduleContext));

  @override
  void onExternalTriggerFired() => events.add(const ExternalTriggerFired());

  @override
  void onExternalTriggerError(Object error, StackTrace stackTrace) =>
      events.add(ExternalTriggerError(error: error, stackTrace: stackTrace));

  @override
  void onCheckIntervalChanged(Duration previous, Duration next) =>
      events.add(CheckIntervalChanged(previous: previous, next: next));

  @override
  void onSlowThresholdChanged(Duration? previous, Duration? next) =>
      events.add(SlowThresholdChanged(previous: previous, next: next));

  @override
  void onDispose() => events.add(const DisposeEvent());
}

/// Marker base for events emitted by [RecordingObserver].
sealed class RecordedEvent {
  const new();
}

/// A recorded [ConnectivityObserver.onStatusChangeEmitted] event.
final class const StatusChangeEmitted({
  /// Status emitted before this one (null on the first emission).
  required final InternetStatus? previous,

  /// The newly emitted status.
  required final InternetStatus next,
}) extends RecordedEvent {
  /// Records the [previous] / [next] pair passed to the observer.
  this;
}

/// A recorded [ConnectivityObserver.onCheckCompleted] event.
final class const CheckCompleted({
  /// Status produced by the completed check.
  required final InternetStatus result,
}) extends RecordedEvent {
  /// Records the [result] passed to the observer.
  this;
}

/// A recorded [ConnectivityObserver.onNextCheckScheduled] event.
final class const NextCheckScheduled({
  /// Delay the scheduler will wait before the next check.
  required final Duration delay,

  /// State the schedule was given to reach [delay].
  required final ScheduleContext scheduleContext,
}) extends RecordedEvent {
  /// Records the [delay] and [scheduleContext] passed to the observer.
  this;
}

/// A recorded [ConnectivityObserver.onExternalTriggerFired] event.
final class ExternalTriggerFired extends RecordedEvent {
  /// Trivial recorder; carries no payload.
  const new();
}

/// A recorded [ConnectivityObserver.onExternalTriggerError] event.
final class const ExternalTriggerError({
  /// Error surfaced by the external-trigger stream.
  required final Object error,

  /// Stack trace accompanying [error].
  required final StackTrace stackTrace,
}) extends RecordedEvent {
  /// Records the [error] / [stackTrace] pair passed to the observer.
  this;
}

/// A recorded [ConnectivityObserver.onCheckIntervalChanged] event.
final class const CheckIntervalChanged({
  /// Interval in effect before the change.
  required final Duration previous,

  /// Interval in effect after the change.
  required final Duration next,
}) extends RecordedEvent {
  /// Records the [previous] / [next] pair passed to the observer.
  this;
}

/// A recorded [ConnectivityObserver.onSlowThresholdChanged] event.
final class const SlowThresholdChanged({
  /// Threshold in effect before the change (null when slow detection was disabled).
  required final Duration? previous,

  /// Threshold in effect after the change (null when slow detection is disabled).
  required final Duration? next,
}) extends RecordedEvent {
  /// Records the [previous] / [next] pair passed to the observer.
  this;
}

/// A recorded [ConnectivityObserver.onDispose] event.
final class DisposeEvent extends RecordedEvent {
  /// Trivial recorder; carries no payload.
  const new();
}
