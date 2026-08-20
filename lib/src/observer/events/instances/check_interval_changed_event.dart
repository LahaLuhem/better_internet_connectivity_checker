part of '../connectivity_event.dart';

/// Emitted when the connection's periodic check interval is reassigned.
///
/// Fires even when [previous] equals [next] — the underlying timer is reset on every assignment.
final class const CheckIntervalChangedEvent({
  /// The interval in effect before the assignment.
  required final Duration previous,

  /// The new interval.
  required final Duration next,
}) extends ConnectivityEvent {
  /// Creates a check-interval-changed event capturing the transition.
  this;

  // Debug-only toString delegation; excluded from coverage.
  // coverage:ignore-start
  @override
  String toString() => 'CheckIntervalChangedEvent(previous: $previous, next: $next)';
  // coverage:ignore-end
}
