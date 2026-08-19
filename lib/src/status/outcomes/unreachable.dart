part of '../internet_status.dart';

/// Status indicating the active aggregation policy considers the internet unreachable.
final class Unreachable extends InternetStatus {
  /// The probes that failed during the check.
  ///
  /// Empty only when no probes ran (a degenerate config the checker's constructor rejects at build time).
  /// Useful for logging the cause without re-running probes.
  final List<ProbeResult> failedProbes;

  /// Creates an [Unreachable] carrying the [failedProbes] that drove the decision.
  const new({required this.failedProbes});

  @override
  String toString() => 'Unreachable(failedProbes: $failedProbes)';
}
