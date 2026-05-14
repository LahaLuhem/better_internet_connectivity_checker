import 'models/probe_result.dart';
import 'models/probe_target.dart';

/// Runs a single connectivity check against one [ProbeTarget].
///
/// Implementations are the swap-in seam for the network layer: the built-in
/// HTTP HEAD probe performs an HTTP HEAD request, but a user can implement
/// this interface to probe via DNS, TCP, a private API, a mocked transport
/// (in tests), or a decorator (e.g. retry-with-backoff) that wraps another
/// probe.
///
/// Probes must complete with a [ProbeResult] in every case — including
/// exceptions raised by the underlying transport — so the aggregation layer
/// always has a value to work with. Exceptions captured during the probe go
/// into [ProbeResult.error].
///
/// State-bearing probes (retry counters, circuit breakers, mock recorders)
/// deserve a proper class with fields, so this stays an interface rather
/// than a function typedef.
// Kept as a class so stateful implementations can hold fields.
// ignore: one_member_abstracts
abstract interface class ConnectivityProbe {
  /// Probes [target] and returns the outcome.
  ///
  /// When [cancelSignal] completes, the probe should abandon any in-flight
  /// I/O and return a [ProbeResult.failure] promptly. The signal is fire-once
  /// and best-effort: probes that cannot honour it (e.g. transports without a
  /// native abort hook) may still run to completion — the contract only asks
  /// that probes that *can* short-circuit *do* so, so the policy layer can
  /// release siblings on first-success / last-failure resolution.
  ///
  /// Probes must tolerate [cancelSignal] completing after the probe has
  /// already finished — that case is a no-op.
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal});
}
