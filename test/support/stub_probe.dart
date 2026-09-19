import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// A [ConnectivityProbe] backed by a closure, for short-circuiting the network in tests.
///
/// Remembers the `cancelSignal` it got per [ProbeTarget], so a test can check the policy forwarded
/// it (or didn't).
final class StubProbe(final Future<ProbeResult> Function(ProbeTarget target) _respond)
    implements ConnectivityProbe {
  final Map<ProbeTarget, Future<void>?> _cancelSignalsByTarget = {};

  /// The `cancelSignal` from the last [probe] call for [target]. Null if there wasn't one, and also
  /// null if [target] was never probed.
  Future<void>? cancelSignalFor(ProbeTarget target) => _cancelSignalsByTarget[target];

  @override
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal}) {
    _cancelSignalsByTarget[target] = cancelSignal;

    return _respond(target);
  }
}
