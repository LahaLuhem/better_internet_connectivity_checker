import '../probe/connectivity_probe.dart';
import '../probe/models/probe_target.dart';
import '../status/internet_status.dart';

/// Aggregates per-probe results into an [InternetStatus].
///
/// Decoupling aggregation from probing lets one probe layer back different reachability semantics:
/// "any of N" (default), "all of N" (strict), or future variants like "k of N". Implementations drive
/// probes their own way (sequential or parallel, racing or waiting) and apply the slow-threshold uniformly —
/// a successful probe exceeding it is marked slow on the [Reachable].
///
/// Stateless by convention, and concrete policies are `const`-constructible so they can be shared.
/// Kept an interface, not a typedef, so state-bearing policies (e.g. a circuit breaker) can hold fields.
abstract interface class ReachabilityPolicy {
  /// Evaluates all [targets] using [probe] and returns the rolled-up status.
  ///
  /// [slowThreshold] may be null to disable slow detection.
  Future<InternetStatus> evaluate({
    required List<ProbeTarget> targets,
    required ConnectivityProbe probe,
    required Duration? slowThreshold,
  });
}
