import 'dart:async';

import '../../probe/connectivity_probe.dart';
import '../../probe/models/probe_result.dart';
import '../../probe/models/probe_target.dart';
import '../../status/internet_status.dart';
import '../reachability_policy.dart';

/// The default: first probe to come back happy wins, and it only gives up once every one has failed.
///
/// Races them all, then cancels the stragglers through [ConnectivityProbe.probe]'s `cancelSignal`.
/// The built-in `HttpProbe` honours that and drops its socket instead of sitting on it until the
/// timeout.
final class const AnyReachablePolicy() implements ReachabilityPolicy {
  /// Creates an [AnyReachablePolicy].
  this;

  @override
  Future<InternetStatus> evaluate({
    required List<ProbeTarget> targets,
    required ConnectivityProbe probe,
    required Duration? slowThreshold,
  }) {
    if (targets.isEmpty) return .syncValue(const Unreachable(failedProbes: []));

    final statusCompleter = Completer<InternetStatus>();
    final cancelCompleter = Completer<void>();
    final failedProbes = <ProbeResult>[];
    var remainingCount = targets.length;

    for (final target in targets) {
      unawaited(
        probe.probe(target, cancelSignal: cancelCompleter.future).then((result) {
          if (statusCompleter.isCompleted) return;

          if (result.isSuccess) {
            statusCompleter.complete(
              Reachable.fromResponseTime(result.responseTime, slowThreshold: slowThreshold),
            );

            return _releasePendingProbes(cancelCompleter);
          }

          failedProbes.add(result);
          remainingCount -= 1;

          if (remainingCount == 0) {
            statusCompleter.complete(Unreachable(failedProbes: failedProbes));
            _releasePendingProbes(cancelCompleter);
          }
        }),
      );
    }

    return statusCompleter.future;
  }

  static void _releasePendingProbes(Completer<void> cancelCompleter) {
    if (!cancelCompleter.isCompleted) cancelCompleter.complete();
  }
}
