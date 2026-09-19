part of '../connectivity_event.dart';

/// An internal check finished, whether or not it moved the status. 1 per tick, plus 1 per
/// trigger.
final class const CheckCompletedEvent(
  /// What the check came back with.
  final InternetStatus result,
) extends ConnectivityEvent {
  /// Creates a [CheckCompletedEvent].
  this;
  // coverage:ignore-start
  @override
  String toString() => 'CheckCompletedEvent(result: $result)';
  // coverage:ignore-end
}
