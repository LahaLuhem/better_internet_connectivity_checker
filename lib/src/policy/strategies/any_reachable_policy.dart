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

    final completer = Completer<InternetStatus>();
    final cancelCompleter = Completer<void>();
    final failures = <ProbeResult>[];
    var remaining = targets.length;

    for (final target in targets) {
      unawaited(
        probe.probe(target, cancelSignal: cancelCompleter.future).then((result) {
          if (completer.isCompleted) return;

          if (result.isSuccess) {
            completer.complete(
              Reachable.fromResponseTime(result.responseTime, slowThreshold: slowThreshold),
            );

            return _releasePendingProbes(cancelCompleter);
          }

          failures.add(result);
          remaining -= 1;

          if (remaining == 0) {
            completer.complete(Unreachable(failedProbes: failures));
            _releasePendingProbes(cancelCompleter);
          }
        }),
      );
    }

    return completer.future;
  }

  static void _releasePendingProbes(Completer<void> cancelCompleter) {
    if (!cancelCompleter.isCompleted) cancelCompleter.complete();
  }
}
