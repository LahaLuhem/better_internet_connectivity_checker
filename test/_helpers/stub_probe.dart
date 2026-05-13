import 'package:ultimate_internet_connectivity_checker/ultimate_internet_connectivity_checker.dart';

/// A [ConnectivityProbe] that delegates to a caller-supplied closure.
///
/// Lives under `test/_helpers/` so the production code stays free of test
/// scaffolding. Use it in policy and connection tests to short-circuit the
/// network layer.
final class StubProbe implements ConnectivityProbe {
  final Future<ProbeResult> Function(ProbeTarget target) _respond;

  StubProbe(this._respond);

  @override
  Future<ProbeResult> probe(ProbeTarget target) => _respond(target);
}
