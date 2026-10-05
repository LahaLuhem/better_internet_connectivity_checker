part of '../connectivity_event.dart';

/// The connection finished tearing down its timer, trigger subscription and status stream.
final class const DisposedEvent() extends ConnectivityEvent {
  /// Creates a [DisposedEvent].
  this;
  // coverage:ignore-start
  @override
  String toString() => 'DisposedEvent()';
  // coverage:ignore-end
}
