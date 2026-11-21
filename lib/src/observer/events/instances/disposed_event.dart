part of '../connectivity_event.dart';

/// The connection finished tearing down its timer, trigger subscription and status stream.
final class const DisposedEvent() extends ConnectivityEvent {
  /// Creates a [DisposedEvent].
  this;

  // No fields to render, so a test could only pin the class name.
  // coverage:ignore-start
  @override
  String toString() => 'DisposedEvent()';
  // coverage:ignore-end
}
