part of '../connectivity_event.dart';

/// Emitted after every scheduled check, carrying the gap the `CheckSchedule` picked for the next one.
///
/// The only way to see a cadence *before* it happens. [CheckCompletedEvent] timestamps let a
/// subscriber infer the gap after the fact, which is no help when the question is why a backed-off
/// checker has gone quiet.
///
/// High-frequency, like [CheckCompletedEvent]: once per check, under every schedule including the
/// default. Does not fire for `InternetConnection.checkOnce`, which never touches the scheduler.
final class const NextCheckScheduledEvent({
  /// How long the scheduler will wait before running the next check.
  required final Duration delay,

  /// What the schedule was given to arrive at [delay].
  required final ScheduleContext scheduleContext,
}) extends ConnectivityEvent {
  /// Creates a next-check-scheduled event capturing the delay and the state behind it.
  this;

  // Debug-only toString delegation; excluded from coverage.
  // coverage:ignore-start
  @override
  String toString() => 'NextCheckScheduledEvent(delay: $delay, scheduleContext: $scheduleContext)';
  // coverage:ignore-end
}
