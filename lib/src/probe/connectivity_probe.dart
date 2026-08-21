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
///
/// Watching [ProbeTarget.timeout] is not an implementer's job. `InternetConnection` caps every probe
/// call at it and fires [probe]'s `cancelSignal` when it runs out, so the only reason to read it is to
/// stop early and free resources sooner.
abstract interface class ConnectivityProbe {
  /// Probes [target] and returns the outcome.
  ///
  /// [cancelSignal] completes when the answer stops mattering: a sibling probe settled it, or the
  /// target's deadline ran out. The probe should then abandon in-flight I/O and return a
  /// [ProbeResult.failure] promptly. It's fire-once and best-effort: probes that can't honour it
  /// (transports without a native abort hook) may run to completion — the contract only asks those
  /// that *can* short-circuit to do so. Probes must tolerate [cancelSignal] completing after they
  /// finish (a no-op).
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal});
}
