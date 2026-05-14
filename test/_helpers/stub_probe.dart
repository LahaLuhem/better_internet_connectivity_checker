import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// A [ConnectivityProbe] that delegates to a caller-supplied closure.
///
/// Lives under `test/_helpers/` so the production code stays free of test
/// scaffolding. Use it in policy and connection tests to short-circuit the
/// network layer.
///
/// Records the `cancelSignal` it was invoked with for each [ProbeTarget],
/// so tests can assert that a policy forwards (or omits) the signal as
/// expected.
final class StubProbe implements ConnectivityProbe {
  final Future<ProbeResult> Function(ProbeTarget target) _respond;
  final Map<ProbeTarget, Future<void>?> _cancelSignalsByTarget = {};

  StubProbe(this._respond);

  /// The `cancelSignal` passed to the most recent [probe] call for
  /// [target], or `null` if [probe] was invoked without a signal — or never
  /// invoked — for that target.
  Future<void>? cancelSignalFor(ProbeTarget target) => _cancelSignalsByTarget[target];

  @override
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal}) {
    _cancelSignalsByTarget[target] = cancelSignal;

    return _respond(target);
  }
}
