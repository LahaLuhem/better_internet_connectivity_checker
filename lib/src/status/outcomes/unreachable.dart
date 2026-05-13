part of '../internet_status.dart';

/// Status indicating that the active aggregation policy considers the
/// internet unreachable.
final class Unreachable extends InternetStatus {
  /// Creates an [Unreachable] status carrying the [failedProbes] that drove
  /// the decision.
  const Unreachable({required this.failedProbes});

  /// The probes that failed during the check.
  ///
  /// Empty only when no probes ran (a degenerate configuration the
  /// constructor of the main checker class rejects at build time). Useful
  /// for logging the underlying cause without re-running probes.
  final List<ProbeResult> failedProbes;
}
