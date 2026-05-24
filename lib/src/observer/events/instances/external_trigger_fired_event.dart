part of '../connectivity_event.dart';

/// Emitted when the external-recheck stream supplied to the connection
/// fires, causing an out-of-band recheck.
final class ExternalTriggerFiredEvent extends ConnectivityEvent {
  /// Creates an external-trigger-fired event.
  const ExternalTriggerFiredEvent();

  // Debug-only toString delegation; excluded from coverage.
  // coverage:ignore-start
  @override
  String toString() => 'ExternalTriggerFiredEvent()';
  // coverage:ignore-end
}
