part of '../connectivity_event.dart';

/// The external-recheck stream fired, so a check is about to run off-cadence.
final class const ExternalTriggerFiredEvent() extends ConnectivityEvent {
  /// Creates an [ExternalTriggerFiredEvent].
  this;

  // No fields to render, so a test could only pin the class name.
  // coverage:ignore-start
  @override
  String toString() => 'ExternalTriggerFiredEvent()';
  // coverage:ignore-end
}
