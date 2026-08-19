import '../../probe/connectivity_probe.dart';
import '../../probe/models/probe_target.dart';
import '../../status/internet_status.dart';
import '../reachability_policy.dart';

/// A strict [ReachabilityPolicy]: every probe must succeed for the connection to count as reachable.
///
/// Fits a curated list modelling "is this *specific* set of services reachable" (e.g. an enterprise requiring fixed internal endpoints).
/// Not for arbitrary public endpoints — any one briefly down would flag a working connection as unreachable.
///
/// Runs all probes in parallel and waits for every one. A [Reachable]'s response time is the
/// slowest successful probe's, since under "all" the slowest dictates user-perceived latency and thus
/// the slow-or-not classification.
final class AllReachablePolicy implements ReachabilityPolicy {
  /// Creates an [AllReachablePolicy].
  const new();

  @override
  Future<InternetStatus> evaluate({
    required List<ProbeTarget> targets,
    required ConnectivityProbe probe,
    required Duration? slowThreshold,
  }) async {
    if (targets.isEmpty) return const Unreachable(failedProbes: []);

    final probeResults = await targets.map(probe.probe).wait;
    final failedProbes = probeResults.where((result) => !result.isSuccess).toList(growable: false);
    if (failedProbes.isNotEmpty) return Unreachable(failedProbes: failedProbes);

    final worstDuration = probeResults
        .map((result) => result.responseTime)
        .reduce((a, b) => a > b ? a : b);

    return Reachable.fromResponseTime(worstDuration, slowThreshold: slowThreshold);
  }
}
