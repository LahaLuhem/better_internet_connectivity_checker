import 'probe_target.dart';

/// Outcome of probing a single [ProbeTarget].
///
/// Every result carries the elapsed time: on success so the aggregation layer can classify a slow-but-reachable
/// connection, on failure to tell "timed out after 3 s" from "DNS failed in 30 ms" (plus any exception caught during the probe).
///
/// Intentionally protocol-agnostic. Probe-specific response data (HTTP headers, DNS records, TCP RST codes, …)
/// lives on the probe's own surface, not here —
/// see [`APPENDIX.md#no-response-data-on-result`](../../APPENDIX.md#no-response-data-on-result).
///
/// The primary constructor is private because [isSuccess] is derived rather than passed: the two
/// public named constructors pin it and redirect here.
final class const ProbeResult._({
  /// The target that was probed.
  required final ProbeTarget target,

  /// Whether the probe succeeded according to its target's predicate.
  required final bool isSuccess,

  /// Wall-clock time the probe took.
  required final Duration responseTime,

  /// The error caught during the probe, if any. Always null on success.
  final Object? error,
}) {
  /// Creates a successful [ProbeResult]. [responseTime] spans request start to response completion.
  const new success({required ProbeTarget target, required Duration responseTime})
    : this._(target: target, isSuccess: true, responseTime: responseTime);

  /// Creates a failed [ProbeResult].
  ///
  /// [responseTime] is the time to failure — the timeout duration on timeout, else the time to the
  /// transport error. [error] is the caught exception, or null when the probe completed but the target's
  /// [ProbeTarget.isSuccess] predicate returned false.
  const new failure({required ProbeTarget target, required Duration responseTime, Object? error})
    : this._(target: target, isSuccess: false, responseTime: responseTime, error: error);

  @override
  String toString() =>
      'ProbeResult('
      'target: $target, '
      'isSuccess: $isSuccess, '
      'responseTime: $responseTime, '
      'error: $error'
      ')';
}
