part of '../connectivity_event.dart';

/// The slow cutoff was reassigned. Either side can be null, meaning slow detection was off. Fires
/// even when nothing changed.
final class const SlowThresholdChangedEvent({
  /// The cutoff before, or null if slow detection was off.
  required final Duration? previous,

  /// The cutoff after, or null if slow detection is now off.
  required final Duration? next,
}) extends ConnectivityEvent {
  /// Creates a [SlowThresholdChangedEvent].
  this;
  // coverage:ignore-start
  @override
  String toString() => 'SlowThresholdChangedEvent(previous: $previous, next: $next)';
  // coverage:ignore-end
}
