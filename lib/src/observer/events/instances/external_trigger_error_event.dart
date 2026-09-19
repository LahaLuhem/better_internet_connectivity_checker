part of '../connectivity_event.dart';

/// The external-recheck stream errored. The connection swallows it to keep the status stream alive,
/// so this event is your only sign it failed.
final class const ExternalTriggerErrorEvent(
  /// What the trigger stream threw.
  final Object error,

  /// Where [error] came from.
  final StackTrace stackTrace,
) extends ConnectivityEvent {
  /// Creates an [ExternalTriggerErrorEvent].
  this;
  // coverage:ignore-start
  @override
  String toString() => 'ExternalTriggerErrorEvent(error: $error)';
  // coverage:ignore-end
}
