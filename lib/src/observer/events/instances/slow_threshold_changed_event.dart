part of '../connectivity_event.dart';

/// Emitted when the connection's slow-classification cutoff is reassigned.
///
/// Either bound may be null (slow classification disabled). Fires even when [previous] equals [next].
final class const SlowThresholdChangedEvent({
  /// The threshold in effect before the assignment, or null if slow classification was disabled.
  required final Duration? previous,

  /// The new threshold, or null if slow classification is now disabled.
  required final Duration? next,
}) extends ConnectivityEvent {
  /// Creates a slow-threshold-changed event capturing the transition.
  this;

  // Debug-only toString delegation; excluded from coverage.
  // coverage:ignore-start
  @override
  String toString() => 'SlowThresholdChangedEvent(previous: $previous, next: $next)';
  // coverage:ignore-end
}
