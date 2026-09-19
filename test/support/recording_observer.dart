import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// Keeps every event it's handed, so a test can assert what [InternetConnection] fired and in what
/// order.
final class RecordingObserver extends ConnectivityObserver {
  /// Creates a [RecordingObserver] with an empty log.
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

/// One thing [RecordingObserver] saw.
sealed class RecordedEvent {
  const new();
}

/// A recorded [ConnectivityObserver.onStatusChangeEmitted] event.
final class const StatusChangeEmitted({
  required final InternetStatus? previous,
  required final InternetStatus next,
}) extends RecordedEvent;

/// A recorded [ConnectivityObserver.onCheckCompleted] event.
final class const CheckCompleted({required final InternetStatus result}) extends RecordedEvent;

/// A recorded [ConnectivityObserver.onNextCheckScheduled] event.
final class const NextCheckScheduled({
  required final Duration delay,
  required final ScheduleContext scheduleContext,
}) extends RecordedEvent;

/// A recorded [ConnectivityObserver.onExternalTriggerFired] event.
final class ExternalTriggerFired extends RecordedEvent {
  const new();
}

/// A recorded [ConnectivityObserver.onExternalTriggerError] event.
final class const ExternalTriggerError({
  required final Object error,
  required final StackTrace stackTrace,
}) extends RecordedEvent;

/// A recorded [ConnectivityObserver.onCheckIntervalChanged] event.
final class const CheckIntervalChanged({
  required final Duration previous,
  required final Duration next,
}) extends RecordedEvent;

/// A recorded [ConnectivityObserver.onSlowThresholdChanged] event.
final class const SlowThresholdChanged({
  required final Duration? previous,
  required final Duration? next,
}) extends RecordedEvent;

/// A recorded [ConnectivityObserver.onDispose] event.
final class DisposeEvent extends RecordedEvent {
  const new();
}
