part of '../internet_status.dart';

/// Status indicating the active aggregation policy considers the internet reachable.
final class const Reachable({
  /// Time spent on the probe whose result drove this status.
  ///
  /// The winning probe's time under any-reachable; the slowest successful probe's under all-reachable,
  /// where the slowest dictates user-perceived latency and thus the [quality].
  required final Duration responseTime,

  /// Whether the connection counts as slow under the active threshold.
  required final ConnectionQuality quality,
}) extends InternetStatus {
  /// Creates a [Reachable] with the probe-derived [responseTime] and pre-computed [quality].
  this;

  /// Convenience constructor that classifies [responseTime] against [slowThreshold].
  ///
  /// A null [slowThreshold] disables slow detection (quality always [ConnectionQuality.good]).
  /// A non-null one marks the connection [ConnectionQuality.slow] when [responseTime] exceeds it.
  factory fromResponseTime(Duration responseTime, {required Duration? slowThreshold}) => Reachable(
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
