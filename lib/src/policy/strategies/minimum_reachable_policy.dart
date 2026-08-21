/// @docImport 'all_reachable_policy.dart';
/// @docImport 'any_reachable_policy.dart';
library;

import 'dart:async';

import '../../probe/connectivity_probe.dart';
import '../../probe/models/probe_result.dart';
import '../../probe/models/probe_target.dart';
import '../../status/internet_status.dart';
import '../reachability_policy.dart';

/// A [ReachabilityPolicy] that needs at least `minimum` probes to succeed.
///
/// Middle ground between [AnyReachablePolicy] and [AllReachablePolicy]: two of four survives one
/// endpoint being down, and won't call a network online off a single host. That last part is what a
/// captive portal whitelisting one target looks like (APPENDIX `what-portal-detection-rests-on`),
/// though whitelisting two beats a `minimum` of two.
///
/// Settles as soon as the count is decided either way and cancels the rest, so [Reachable]'s response
/// time is the deciding success and [Unreachable] lists only the `targets - minimum + 1` failures that
/// settled it. Asking for more than the target list holds asserts in debug, reports [Unreachable] in
/// release.
final class const MinimumReachablePolicy({
  /// How many probes must succeed. A `minimum` of 1 is [AnyReachablePolicy].
  required final int _minimum,
}) implements ReachabilityPolicy {
  /// Creates a policy that needs `minimum` successes.
  this : assert(_minimum >= 1, 'minimum must be at least 1');

  @override
  Future<InternetStatus> evaluate({
    required List<ProbeTarget> targets,
    required ConnectivityProbe probe,
    required Duration? slowThreshold,
  }) {
    assert(
      targets.length >= _minimum,
      'minimum ($_minimum) exceeds the target count (${targets.length}), so no check can pass',
    );
    if (targets.length < _minimum) return Future.value(const Unreachable(failedProbes: []));

    final completer = Completer<InternetStatus>();
    final cancelCompleter = Completer<void>();
    final failures = <ProbeResult>[];
    var successes = 0;

    void releasePendingProbes() {
      if (!cancelCompleter.isCompleted) cancelCompleter.complete();
    }

    for (final target in targets) {
      unawaited(
        probe.probe(target, cancelSignal: cancelCompleter.future).then((result) {
          if (completer.isCompleted) return;

          if (result.isSuccess) {
            successes += 1;
            if (successes < _minimum) return;

            completer.complete(
              Reachable.fromResponseTime(result.responseTime, slowThreshold: slowThreshold),
            );

            return releasePendingProbes();
          }

          failures.add(result);
          if (targets.length - failures.length >= _minimum) return;

          completer.complete(Unreachable(failedProbes: failures));
          releasePendingProbes();
        }),
      );
    }

    return completer.future;
  }
}
