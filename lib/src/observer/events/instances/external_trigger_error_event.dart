part of '../connectivity_event.dart';

/// Emitted when the external-recheck stream surfaces an error.
///
/// The connection swallows the error (the trigger is best-effort and must not disturb the status stream's listeners),
/// so this event is a subscriber's only signal that the trigger failed.
final class ExternalTriggerErrorEvent extends ConnectivityEvent {
  /// The error raised by the external-trigger stream.
  final Object error;

  /// The stack trace associated with [error].
  final StackTrace stackTrace;

  /// Creates an external-trigger-error event carrying [error] and [stackTrace].
  const new(this.error, this.stackTrace);

  // Debug-only toString delegation; excluded from coverage.
  // coverage:ignore-start
  @override
  String toString() => 'ExternalTriggerErrorEvent(error: $error)';
  // coverage:ignore-end
}
