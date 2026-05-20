part of '../internet_status.dart';

/// Status indicating that the active aggregation policy considers the
/// internet reachable.
final class Reachable extends InternetStatus {
  /// Time spent on the probe whose result drove this status.
  ///
  /// For any-reachable policies this is the winning probe's response time;
  /// for all-reachable policies this is the slowest of the successful
  /// probes — under "all", the slowest probe dictates the user-perceived
  /// latency and therefore the [quality] classification.
  final Duration responseTime;

  /// Whether the connection counts as slow under the active threshold.
  final ConnectionQuality quality;

  /// Creates a [Reachable] status with the probe-derived [responseTime] and
  /// pre-computed [quality].
  const Reachable({required this.responseTime, required this.quality});

  /// Convenience constructor that classifies [responseTime] against
  /// [slowThreshold].
  ///
  /// A null [slowThreshold] disables slow detection — the quality is always
  /// [ConnectionQuality.good]. A non-null threshold classifies the
  /// connection as [ConnectionQuality.slow] when [responseTime] exceeds it.
  factory Reachable.fromResponseTime(Duration responseTime, {required Duration? slowThreshold}) =>
      Reachable(
        responseTime: responseTime,
        quality: slowThreshold != null && responseTime > slowThreshold ? .slow : .good,
      );

  @override
  String toString() =>
      'Reachable('
      'responseTime: $responseTime, '
      'quality: $quality'
      ')';
}
