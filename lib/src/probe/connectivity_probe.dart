import 'models/probe_result.dart';
import 'models/probe_target.dart';

/// Checks one [ProbeTarget]. Swap it out to probe over DNS, TCP, your own API, or a mock.
///
/// Never throw: catch the transport error and put it in [ProbeResult.error], so the layer above
/// always gets an answer. It's an interface rather than a typedef so a probe can keep state, like a
/// retry counter or a circuit breaker.
///
/// You don't have to watch [ProbeTarget.timeout]. `InternetConnection` caps every call at it, and
/// [probe]'s `cancelSignal` tells you when. Read it only if you want to bail out sooner. Why the
/// deadline lives up there: see [Appendix](https://github.com/LahaLuhem/better_internet_connectivity_checker/blob/main/APPENDIX.md#why-the-coordinator-keeps-the-deadline).
abstract interface class ConnectivityProbe {
  /// Probes [target] and returns what happened.
  ///
  /// [cancelSignal] completes when nobody needs the answer any more, either because a sibling probe
  /// settled it or the deadline ran out. Drop your I/O and return a [ProbeResult.failure] if you
  /// can. It fires once, it's best-effort, and it may well complete after you've already finished.
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal});
}
