/// @docImport '../../status/models/connection_quality.dart';
library;

import '../../status/internet_status.dart';

/// What a `CheckSchedule` gets to look at when picking the next gap. One object rather than loose
/// parameters, so a later release can add a field without breaking your implementation.
final class const ScheduleContext({
  required final Duration _baseInterval,
  required final int _consecutiveFailures,
  required final InternetStatus _lastStatus,
}) {
  /// Creates a [ScheduleContext].
  this : assert(_consecutiveFailures >= 0, 'consecutiveFailures cannot be negative');

  /// The configured `InternetConnection.checkInterval`. A growing schedule starts from here, so
  /// reassigning it at runtime rescales the whole curve.
  Duration get baseInterval => _baseInterval;

  /// How many checks in a row came back [Unreachable], this one included. Back to zero the moment
  /// one succeeds, so a schedule reading only this needs no state of its own.
  int get consecutiveFailures => _consecutiveFailures;

  /// What the check just produced, so a schedule can react to [ConnectionQuality] too and not only
  /// to reachability.
  InternetStatus get lastStatus => _lastStatus;

  @override
  String toString() =>
      'ScheduleContext('
      'baseInterval: $baseInterval, '
      'consecutiveFailures: $consecutiveFailures, '
      'lastStatus: $lastStatus'
      ')';
}
