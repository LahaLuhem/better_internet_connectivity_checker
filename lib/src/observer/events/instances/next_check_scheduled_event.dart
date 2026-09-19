part of '../connectivity_event.dart';

/// The gap the schedule picked before the next check, which is the only way to see a cadence before
/// it happens. Handy when a backed-off checker has gone quiet and you want to know for how long.
///
/// One per check, as often as [CheckCompletedEvent]. Never for `InternetConnection.checkOnce`.
final class const NextCheckScheduledEvent({
  /// How long until the next check.
  required final Duration delay,

  /// What the schedule saw when it picked [delay].
  required final ScheduleContext scheduleContext,
}) extends ConnectivityEvent {
  /// Creates a [NextCheckScheduledEvent].
  this;
  // coverage:ignore-start
  @override
  String toString() => 'NextCheckScheduledEvent(delay: $delay, scheduleContext: $scheduleContext)';
  // coverage:ignore-end
}
