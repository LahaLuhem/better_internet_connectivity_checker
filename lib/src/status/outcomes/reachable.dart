part of '../internet_status.dart';

/// The policy reckons the internet is reachable.
final class const Reachable({
  /// Time taken by the probe that settled it. Under any-of-N that's whichever won, under all-of-N
  /// it's the slowest, since the slowest is what a user actually feels.
  required final Duration responseTime,

  /// Whether [responseTime] cleared the slow threshold.
  required final ConnectionQuality quality,
}) extends InternetStatus {
  /// Creates a [Reachable] from an already-worked-out [quality].
  this;

  /// Creates a [Reachable], sorting out [quality] from [responseTime] itself. A null [slowThreshold]
  /// means always [ConnectionQuality.good].
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
