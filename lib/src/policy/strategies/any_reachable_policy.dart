import 'dart:async';

import '../../probe/connectivity_probe.dart';
import '../../probe/models/probe_result.dart';
import '../../probe/models/probe_target.dart';
import '../../status/internet_status.dart';
import '../reachability_policy.dart';

/// The default [ReachabilityPolicy]: succeed on the first probe that succeeds, fail only once every
/// probe has failed.
///
/// Races all probes in parallel. On the first success, returns [Reachable] immediately and cancels
/// the rest via [ConnectivityProbe.probe]'s `cancelSignal` — probes that honour it (the built-in `HttpProbe` does)
/// abort at the transport layer rather than leaving sockets dangling for the rest of their timeout.
/// If every probe fails, returns [Unreachable] carrying all the failures.
final class AnyReachablePolicy implements ReachabilityPolicy {
  /// Creates an [AnyReachablePolicy].
  const new();

  @override
  Future<InternetStatus> evaluate({
    required List<ProbeTarget> targets,
    required ConnectivityProbe probe,
    required Duration? slowThreshold,
  }) {
    if (targets.isEmpty) return Future.value(const Unreachable(failedProbes: []));

    final completer = Completer<InternetStatus>();
    final cancelCompleter = Completer<void>();
    final failures = <ProbeResult>[];
    var remaining = targets.length;

    void releasePendingProbes() {
      if (!cancelCompleter.isCompleted) cancelCompleter.complete();
    }

    for (final target in targets) {
      unawaited(
        probe.probe(target, cancelSignal: cancelCompleter.future).then((result) {
          if (completer.isCompleted) return;

          if (result.isSuccess) {
            completer.complete(
              Reachable.fromResponseTime(result.responseTime, slowThreshold: slowThreshold),
            );

            return releasePendingProbes();
          }

          failures.add(result);
          remaining -= 1;

          if (remaining == 0) {
            completer.complete(Unreachable(failedProbes: failures));
            releasePendingProbes();
          }
        }),
      );
    }

    return completer.future;
  }
}
