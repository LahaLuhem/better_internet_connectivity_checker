part of '../connectivity_event.dart';

/// Emitted after every internal check completes, regardless of whether the
/// result changed the emitted status. Mirrors the cadence of the periodic
/// timer plus any external-trigger-driven rechecks.
final class CheckCompletedEvent extends ConnectivityEvent {
  /// The status produced by the completed check.
  final InternetStatus result;

  /// Creates a check-completed event carrying the check's [result].
  const CheckCompletedEvent(this.result);

  @override
  String toString() => 'CheckCompletedEvent(result: $result)';
}
