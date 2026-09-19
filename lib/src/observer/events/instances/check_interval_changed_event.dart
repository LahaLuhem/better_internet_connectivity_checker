part of '../connectivity_event.dart';

/// The periodic check interval was reassigned. Fires even when nothing changed, because every
/// assignment resets the timer.
final class const CheckIntervalChangedEvent({
  /// The interval before.
  required final Duration previous,

  /// The interval after.
  required final Duration next,
}) extends ConnectivityEvent {
  /// Creates a [CheckIntervalChangedEvent].
  this;
  // coverage:ignore-start
  @override
  String toString() => 'CheckIntervalChangedEvent(previous: $previous, next: $next)';
  // coverage:ignore-end
}
