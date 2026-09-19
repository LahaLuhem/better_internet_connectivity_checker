part of '../internet_status.dart';

/// The policy reckons the internet is unreachable.
final class const Unreachable({
  /// The probes that failed, so you can log why without running them again. Only ever empty when no
  /// probes ran at all, which the constructor rejects.
  required final List<ProbeResult> failedProbes,
}) extends InternetStatus {
  /// Creates an [Unreachable].
  this;

  @override
  String toString() => 'Unreachable(failedProbes: $failedProbes)';
}
