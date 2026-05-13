import 'probe_target.dart';

/// Outcome of probing a single [ProbeTarget].
///
/// Successful results carry the elapsed time so the aggregation layer can
/// classify a slow-but-reachable connection. Failed results carry the
/// elapsed time too — useful for distinguishing "timed out after 3 s" from
/// "DNS failed in 30 ms" — plus any exception caught during the probe.
///
/// Intentionally protocol-agnostic. Probe-specific response data (HTTP
/// headers, DNS records, TCP RST codes, …) lives on the probe's own
/// surface, not here — see
/// [`APPENDIX.md#no-response-data-on-result`](../../APPENDIX.md#no-response-data-on-result).
final class ProbeResult {
  /// The target that was probed.
  final ProbeTarget target;

  /// Whether the probe succeeded according to its target's predicate.
  final bool isSuccess;

  /// Wall-clock time the probe took.
  final Duration responseTime;

  /// The error caught during the probe, if any. Always null on success.
  final Object? error;

  /// Creates a successful [ProbeResult].
  ///
  /// [responseTime] is the wall-clock duration the probe took, measured from
  /// request start to response completion.
  const ProbeResult.success({required this.target, required this.responseTime})
    : isSuccess = true,
      error = null;

  /// Creates a failed [ProbeResult].
  ///
  /// [responseTime] is the wall-clock duration the probe took before
  /// failing — the timeout duration on timeout, or the time to hit the
  /// transport error otherwise.
  ///
  /// [error] is the caught exception, if any. Null when the probe ran to
  /// completion but the target's [ProbeTarget.isSuccess] predicate returned
  /// false.
  const ProbeResult.failure({required this.target, required this.responseTime, this.error})
    : isSuccess = false;
}
