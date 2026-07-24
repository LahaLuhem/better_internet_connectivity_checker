part of '../internet_status.dart';

/// Status indicating the active aggregation policy considers the internet reachable.
final class Reachable extends InternetStatus {
  /// Time spent on the probe whose result drove this status.
  ///
  /// The winning probe's time under any-reachable; the slowest successful probe's under all-reachable,
  /// where the slowest dictates user-perceived latency and thus the [quality].
  final Duration responseTime;

  /// Whether the connection counts as slow under the active threshold.
  final ConnectionQuality quality;

  /// Creates a [Reachable] with the probe-derived [responseTime] and pre-computed [quality].
  const Reachable({required this.responseTime, required this.quality});

  /// Convenience constructor that classifies [responseTime] against [slowThreshold].
  ///
  /// A null [slowThreshold] disables slow detection (quality always [ConnectionQuality.good]).
  /// A non-null one marks the connection [ConnectionQuality.slow] when [responseTime] exceeds it.
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
