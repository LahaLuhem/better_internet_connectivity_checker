part of '../internet_status.dart';

/// Status indicating the active aggregation policy considers the internet unreachable.
final class const Unreachable({
  /// The probes that failed during the check.
  ///
  /// Empty only when no probes ran (a degenerate config the checker's constructor rejects at build time).
  /// Useful for logging the cause without re-running probes.
  required final List<ProbeResult> failedProbes,
}) extends InternetStatus {
  /// Creates an [Unreachable] carrying the [failedProbes] that drove the decision.
  this;

  @override
  String toString() => 'Unreachable(failedProbes: $failedProbes)';
}
