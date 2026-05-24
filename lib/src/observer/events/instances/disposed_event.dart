part of '../connectivity_event.dart';

/// Emitted once when the connection finishes tearing down its timer,
/// trigger subscription, and status stream.
final class DisposedEvent extends ConnectivityEvent {
  /// Creates a disposed event.
  const DisposedEvent();

  // Debug-only toString delegation; excluded from coverage.
  // coverage:ignore-start
  @override
  String toString() => 'DisposedEvent()';
  // coverage:ignore-end
}
