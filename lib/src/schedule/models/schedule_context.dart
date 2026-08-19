/// @docImport '../../status/models/connection_quality.dart';
library;

import '../../status/internet_status.dart';

/// What a `CheckSchedule` gets to look at when deciding the gap before the next check.
///
/// Immutable, built fresh after every scheduled check. Passed as one object rather than as loose
/// parameters so a later release can add a field without breaking existing implementations.
final class const ScheduleContext({
  required final Duration _baseInterval,
  required final int _consecutiveFailures,
  required final InternetStatus _lastStatus,
}) {
  /// Creates a [ScheduleContext].
  this : assert(_consecutiveFailures >= 0, 'consecutiveFailures cannot be negative');

  /// The configured `InternetConnection.checkInterval`.
  ///
  /// A schedule that grows its delay treats this as the starting point, so reassigning
  /// `checkInterval` at runtime rescales the whole curve.
  Duration get baseInterval => _baseInterval;

  /// How many checks in a row have come back [Unreachable], including [lastStatus].
  ///
  /// Zero whenever the last check was [Reachable], so a schedule reading only this field needs no
  /// state of its own.
  int get consecutiveFailures => _consecutiveFailures;

  /// The status the check just produced.
  ///
  /// Lets a schedule react to [ConnectionQuality] as well as reachability, which
  /// [consecutiveFailures] alone cannot express.
  InternetStatus get lastStatus => _lastStatus;

  @override
  String toString() =>
      'ScheduleContext('
      'baseInterval: $baseInterval, '
      'consecutiveFailures: $consecutiveFailures, '
      'lastStatus: $lastStatus'
      ')';
}
