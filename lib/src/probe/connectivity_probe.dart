import 'models/probe_result.dart';
import 'models/probe_target.dart';

/// Runs a single connectivity check against one [ProbeTarget].
///
/// The swap-in seam for the network layer: the built-in probe issues HTTP HEAD, but implementations
/// can probe via DNS, TCP, a private API, a test mock, or a decorator (e.g. retry-with-backoff)
/// wrapping another probe.
///
/// A probe must always complete with a [ProbeResult] — transport exceptions included, captured in
/// [ProbeResult.error] — so the aggregation layer always has a value. Kept an interface, not a
/// function typedef, so state-bearing probes (retry counters, circuit breakers, mock recorders) can
/// hold fields.
// Kept as an interface (not a typedef) so stateful implementations can hold fields.
// ignore: one_member_abstracts
abstract interface class ConnectivityProbe {
  /// Probes [target] and returns the outcome.
  ///
  /// When [cancelSignal] completes, the probe should abandon in-flight I/O and return a [ProbeResult.failure]
  /// promptly. It's fire-once and best-effort: probes that can't honour it (transports without a native abort hook)
  /// may run to completion — the contract only asks those that *can* short-circuit to do so, letting
  /// the policy release siblings on first-success / last-failure. Probes must tolerate [cancelSignal]
  /// completing after they finish (a no-op).
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal});
}
