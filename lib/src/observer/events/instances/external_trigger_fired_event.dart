part of '../connectivity_event.dart';

/// The external-recheck stream fired, so a check is about to run off-cadence.
final class ExternalTriggerFiredEvent extends ConnectivityEvent {
  /// Creates an [ExternalTriggerFiredEvent].
  const new();
  // coverage:ignore-start
  @override
  String toString() => 'ExternalTriggerFiredEvent()';
  // coverage:ignore-end
}
