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
/// first success, returns a [Reachable] status immediately and signals
/// pending probes to cancel via [ConnectivityProbe.probe]'s `cancelSignal`.
/// Probes that honour the signal — the built-in `HttpProbe` does — abort
/// at the transport layer so siblings do not leave sockets dangling for the
/// remainder of their timeout.
///
/// If every probe fails, returns an [Unreachable] status carrying all
/// collected failures.
final class AnyReachablePolicy implements ReachabilityPolicy {
  /// Creates an [AnyReachablePolicy].
  const AnyReachablePolicy();

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
            releasePendingProbes();

            return;
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
