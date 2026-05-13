import '../../probe/connectivity_probe.dart';
import '../../probe/models/probe_target.dart';
import '../../status/internet_status.dart';
import '../reachability_policy.dart';

/// A strict [ReachabilityPolicy]: every probe must succeed for the connection
/// to be considered reachable.
///
/// Useful when the probe list is curated to model "is this *specific* set of
/// services reachable" (e.g. an enterprise environment that hard-requires a
/// fixed set of internal endpoints). Not recommended with arbitrary public
/// endpoints — any one of them being briefly down would flag a working
/// connection as unreachable.
///
/// Runs every probe in parallel and waits for all of them. The reported
/// response time on a [Reachable] status is the slowest of the successful
/// probes — under "all", the slowest probe dictates the user-perceived
/// latency and therefore the slow-or-not classification.
final class AllReachablePolicy implements ReachabilityPolicy {
  /// Creates an [AllReachablePolicy].
  const AllReachablePolicy();

  @override
  Future<InternetStatus> evaluate({
    required Iterable<ProbeTarget> targets,
    required ConnectivityProbe probe,
    required Duration? slowThreshold,
  }) async {
    final targetList = targets.toList(growable: false);
    if (targetList.isEmpty) {
      return const Unreachable(failedProbes: []);
    }

    final results = await Future.wait(targetList.map(probe.probe));
    final failures = results.where((r) => !r.isSuccess).toList(growable: false);
    if (failures.isNotEmpty) {
      return Unreachable(failedProbes: failures);
    }

    final worst = results.map((r) => r.responseTime).reduce((a, b) => a > b ? a : b);

    return Reachable.fromResponseTime(worst, slowThreshold: slowThreshold);
  }
}
