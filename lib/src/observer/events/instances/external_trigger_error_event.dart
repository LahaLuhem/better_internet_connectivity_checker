part of '../connectivity_event.dart';

/// Emitted when the external-recheck stream surfaces an error.
///
/// The error is swallowed by the connection — the trigger is best-effort
/// and its errors must not propagate to the status stream's listeners —
/// so this event is the only signal a subscriber gets that the trigger
/// has failed.
final class ExternalTriggerErrorEvent extends ConnectivityEvent {
  /// The error raised by the external-trigger stream.
  final Object error;

  /// The stack trace associated with [error].
  final StackTrace stackTrace;

  /// Creates an external-trigger-error event carrying [error] and
  /// [stackTrace].
  const ExternalTriggerErrorEvent(this.error, this.stackTrace);

  @override
  String toString() => 'ExternalTriggerErrorEvent(error: $error)';
}
