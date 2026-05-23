part of '../connectivity_event.dart';

/// Emitted once when the connection finishes tearing down its timer,
/// trigger subscription, and status stream.
final class DisposedEvent extends ConnectivityEvent {
  /// Creates a disposed event.
  const DisposedEvent();

  @override
  String toString() => 'DisposedEvent()';
}
