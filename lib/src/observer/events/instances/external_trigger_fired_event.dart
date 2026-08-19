part of '../connectivity_event.dart';

/// Emitted when the connection's external-recheck stream fires, causing an out-of-band recheck.
final class ExternalTriggerFiredEvent extends ConnectivityEvent {
  /// Creates an external-trigger-fired event.
  const new();

  // Debug-only toString delegation; excluded from coverage.
  // coverage:ignore-start
  @override
  String toString() => 'ExternalTriggerFiredEvent()';
  // coverage:ignore-end
}
