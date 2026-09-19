import '../../probe/connectivity_probe.dart';
import '../../probe/models/probe_target.dart';
import '../../status/internet_status.dart';
import '../reachability_policy.dart';

/// Every probe has to succeed. Good for "are these particular services up", bad for public
/// endpoints, where one of them having a wobble marks a perfectly fine connection as offline.
///
/// Runs them all in parallel and waits for the lot. [Reachable.responseTime] is the slowest of them,
/// because the slowest is what the user actually feels.
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
