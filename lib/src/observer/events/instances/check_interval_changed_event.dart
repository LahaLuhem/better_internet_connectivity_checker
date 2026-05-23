part of '../connectivity_event.dart';

/// Emitted when the connection's periodic check interval is reassigned.
///
/// Fires even when [previous] equals [next] — the underlying timer is
/// reset on every assignment.
final class CheckIntervalChangedEvent extends ConnectivityEvent {
  /// The interval that was in effect before the assignment.
  final Duration previous;

  /// The new interval that took effect.
  final Duration next;

  /// Creates a check-interval-changed event capturing the transition.
  const CheckIntervalChangedEvent({required this.previous, required this.next});

  @override
  String toString() => 'CheckIntervalChangedEvent(previous: $previous, next: $next)';
}
