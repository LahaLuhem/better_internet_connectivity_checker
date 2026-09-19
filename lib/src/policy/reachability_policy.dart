import '../probe/connectivity_probe.dart';
import '../probe/models/probe_target.dart';
import '../status/internet_status.dart';

/// Rolls a pile of probe results into one [InternetStatus]: any-of-N, all-of-N, k-of-N, or whatever
/// you write. Why a strategy and not a bool: [Appendix](https://github.com/LahaLuhem/better_internet_connectivity_checker/blob/main/APPENDIX.md#policy-strategy-not-bool-flag).
///
/// Run the probes however you like, sequentially or racing. Stateless by convention, but it's an
/// interface rather than a typedef so a policy that needs state, a circuit breaker say, can keep it.
abstract interface class ReachabilityPolicy {
  /// Runs [probe] over every one of [targets] and rolls the results up. A null [slowThreshold] turns
  /// slow detection off.
  Future<InternetStatus> evaluate({
    required List<ProbeTarget> targets,
    required ConnectivityProbe probe,
    required Duration? slowThreshold,
  });
}
