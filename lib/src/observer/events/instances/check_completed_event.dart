part of '../connectivity_event.dart';

/// Emitted after every internal check completes, whether or not the result changed the emitted status.
/// Mirrors the periodic timer's cadence plus any trigger-driven rechecks.
final class const CheckCompletedEvent(
  /// The status produced by the completed check.
  final InternetStatus result,
) extends ConnectivityEvent {
  /// Creates a check-completed event carrying the check's [result].
  this;

  // Debug-only toString delegation; excluded from coverage.
  // coverage:ignore-start
  @override
  String toString() => 'CheckCompletedEvent(result: $result)';
  // coverage:ignore-end
}
