import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// Intentionally-slow probe targets for the Live-stream demo.
///
/// The library's default targets are CDN-fronted reliability endpoints
/// that respond in tens of milliseconds — too fast for the slow-threshold
/// slider (range 0–2000 ms) to meaningfully exercise both
/// [ConnectionQuality] classifications. Both Postman-Echo and httpbin
/// expose `delay/<seconds>` endpoints that block server-side for the
/// requested duration before returning, so probe response time lands
/// inside the slider's range with a transition near the 1-second mark.
///
/// **Operator-diversity trade-off.** Two operators (Postman and the
/// community-maintained `httpbin.org`) instead of the library default's
/// curated cross-operator list. The library's default list is
/// deliberately operator-diverse for production use; this demo
/// narrows that for predictable latency. If both happen to be down, the
/// demo surfaces an [Unreachable] status — also instructive in a
/// Live-stream view. (Originally `httpstat.us`; switched after it became
/// unreachable from this developer's network. If the alternatives go the
/// same way, swap them out for any other `delay/<n>` mirror.)
abstract final class ConstProbeTargets {
  /// Probe targets used by the Live-stream demo. Two operators with
  /// equivalent `delay/<seconds>` semantics — the faster of the two wins
  /// under [AnyReachablePolicy] (the package default); the slower is the
  /// redundancy path if the primary is unreachable. Integer-second delay
  /// is the floor `httpbin.org` accepts; sub-second precision is not
  /// available cross-operator. Slider transition lands near 1000 ms
  /// (the nominal delay plus per-request TLS / TCP overhead).
  static final liveStreamSlowTargets = [
    ProbeTarget(uri: Uri.https('postman-echo.com', 'delay/1')),
    ProbeTarget(uri: Uri.https('httpbin.org', 'delay/1')),
  ];
}
