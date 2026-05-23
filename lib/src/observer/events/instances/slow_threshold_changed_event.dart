part of '../connectivity_event.dart';

/// Emitted when the connection's slow-classification cutoff is reassigned.
///
/// Either [previous] or [next] may be null (slow classification disabled).
/// Fires even when [previous] equals [next].
final class SlowThresholdChangedEvent extends ConnectivityEvent {
  /// The threshold that was in effect before the assignment, or null if
  /// slow classification was disabled.
  final Duration? previous;

  /// The new threshold that took effect, or null if slow classification
  /// is now disabled.
  final Duration? next;

  /// Creates a slow-threshold-changed event capturing the transition.
  const SlowThresholdChangedEvent({required this.previous, required this.next});

  @override
  String toString() => 'SlowThresholdChangedEvent(previous: $previous, next: $next)';
}
