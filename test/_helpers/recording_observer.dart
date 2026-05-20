import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// A [ConnectivityObserver] that records every event it receives.
///
/// Lives under `test/_helpers/` so production code stays free of test
/// scaffolding. Use it to assert that [InternetConnection] fires the
/// expected lifecycle callbacks in the expected order with the expected
/// payloads.
final class RecordingObserver extends ConnectivityObserver {
  /// Creates a [RecordingObserver] starting with an empty event log.
  RecordingObserver();

  /// Every event the observer has received, in order.
  final List<RecordedEvent> events = [];

  @override
  void onStatusChangeEmitted(InternetStatus? previous, InternetStatus next) =>
      events.add(StatusChangeEmitted(previous: previous, next: next));

  @override
  void onCheckCompleted(InternetStatus result) => events.add(CheckCompleted(result: result));

  @override
  void onExternalTriggerFired() => events.add(const ExternalTriggerFired());

  @override
  void onExternalTriggerError(Object error, StackTrace stackTrace) =>
      events.add(ExternalTriggerError(error: error, stackTrace: stackTrace));

  @override
  void onCheckIntervalChanged(Duration previous, Duration next) =>
      events.add(CheckIntervalChanged(previous: previous, next: next));

  @override
  void onDispose() => events.add(const DisposeEvent());
}

/// Marker base for events emitted by [RecordingObserver].
sealed class RecordedEvent {
  const RecordedEvent();
}

/// A recorded [ConnectivityObserver.onStatusChangeEmitted] event.
final class StatusChangeEmitted extends RecordedEvent {
  /// Status emitted before this one (null on the first emission).
  final InternetStatus? previous;

  /// The newly emitted status.
  final InternetStatus next;

  /// Records the [previous] / [next] pair passed to the observer.
  const StatusChangeEmitted({required this.previous, required this.next});
}

/// A recorded [ConnectivityObserver.onCheckCompleted] event.
final class CheckCompleted extends RecordedEvent {
  /// Status produced by the completed check.
  final InternetStatus result;

  /// Records the [result] passed to the observer.
  const CheckCompleted({required this.result});
}

/// A recorded [ConnectivityObserver.onExternalTriggerFired] event.
final class ExternalTriggerFired extends RecordedEvent {
  /// Trivial recorder; carries no payload.
  const ExternalTriggerFired();
}

/// A recorded [ConnectivityObserver.onExternalTriggerError] event.
final class ExternalTriggerError extends RecordedEvent {
  /// Error surfaced by the external-trigger stream.
  final Object error;

  /// Stack trace accompanying [error].
  final StackTrace stackTrace;

  /// Records the [error] / [stackTrace] pair passed to the observer.
  const ExternalTriggerError({required this.error, required this.stackTrace});
}

/// A recorded [ConnectivityObserver.onCheckIntervalChanged] event.
final class CheckIntervalChanged extends RecordedEvent {
  /// Interval in effect before the change.
  final Duration previous;

  /// Interval in effect after the change.
  final Duration next;

  /// Records the [previous] / [next] pair passed to the observer.
  const CheckIntervalChanged({required this.previous, required this.next});
}

/// A recorded [ConnectivityObserver.onDispose] event.
final class DisposeEvent extends RecordedEvent {
  /// Trivial recorder; carries no payload.
  const DisposeEvent();
}
