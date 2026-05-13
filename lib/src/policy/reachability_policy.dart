import '../probe/connectivity_probe.dart';
import '../probe/models/probe_target.dart';
import '../status/internet_status.dart';

/// Aggregates per-probe results into an [InternetStatus].
///
/// Decoupling aggregation from probing lets the same probe layer support
/// different reachability semantics — "any one of N suffices" (default),
/// "all of N must succeed" (strict), or future variants like "k of N".
///
/// Implementations drive the probe (sequentially or in parallel, racing or
/// waiting) according to their own semantics, and apply the slow-threshold
/// argument uniformly: a successful probe whose response time exceeds it is
/// classified as slow on the returned [Reachable] status.
///
/// Stateless by convention: implementations should not hold per-call state.
/// Concrete policies are `const`-constructible so they can be shared.
///
/// State-bearing policies (e.g. a circuit-breaker policy that remembers
/// recent failures) deserve a proper class, so this stays an interface
/// rather than a function typedef.
// Kept as a class so stateful policies can hold fields.
// ignore: one_member_abstracts
abstract interface class ReachabilityPolicy {
  /// Evaluates all [targets] using [probe] and returns the rolled-up status.
  ///
  /// [slowThreshold] may be null to disable slow detection.
  Future<InternetStatus> evaluate({
    required Iterable<ProbeTarget> targets,
    required ConnectivityProbe probe,
    required Duration? slowThreshold,
  });
}
