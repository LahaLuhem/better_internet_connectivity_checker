import 'dart:async';

import '../../probe/connectivity_probe.dart';
import '../../probe/models/probe_result.dart';
import '../../probe/models/probe_target.dart';
import '../../status/internet_status.dart';
import '../reachability_policy.dart';

/// The default [ReachabilityPolicy]: succeed on the first probe that
/// succeeds, fail only after every probe fails.
///
/// Runs every probe in parallel and races them for the first success. On the
/// first success, returns a [Reachable] status immediately — pending probes
/// are not awaited (though the underlying network requests continue to
/// completion; the standard `package:http` client has no cancel hook).
///
/// If every probe fails, returns an [Unreachable] status carrying all
/// collected failures.
final class AnyReachablePolicy implements ReachabilityPolicy {
  /// Creates an [AnyReachablePolicy].
  const AnyReachablePolicy();

  @override
  Future<InternetStatus> evaluate({
    required Iterable<ProbeTarget> targets,
    required ConnectivityProbe probe,
    required Duration? slowThreshold,
  }) {
    final targetList = targets.toList(growable: false);
    if (targetList.isEmpty) {
      return Future.value(const Unreachable(failedProbes: []));
    }

    final completer = Completer<InternetStatus>();
    final failures = <ProbeResult>[];
    var remaining = targetList.length;

    for (final target in targetList) {
      unawaited(
        probe.probe(target).then((result) {
          if (completer.isCompleted) return;

          if (result.isSuccess) {
            completer.complete(
              Reachable.fromResponseTime(result.responseTime, slowThreshold: slowThreshold),
            );

            return;
          }

          failures.add(result);
          remaining -= 1;

          if (remaining == 0) {
            completer.complete(Unreachable(failedProbes: failures));
          }
        }),
      );
    }

    return completer.future;
  }
}
