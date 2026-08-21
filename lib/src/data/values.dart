import '../probe/models/probe_target.dart';
import 'models/const_uri.dart';

/// Internal default values for the package's own classes.
///
/// Grouped in an `abstract final` class so call sites read `Values.defaultX` — the prefix makes the
/// origin obvious. Not exported; consumers configure these via constructor arguments.
abstract final class Values {
  /// Default periodic check interval used by `InternetConnection` when no `checkInterval` argument
  /// is provided.
  static const defaultCheckInterval = Duration(seconds: 10);

  /// Default per-probe timeout used by [ProbeTarget] when no `timeout` argument is provided.
  static const defaultProbeTimeout = Duration(seconds: 3);

  /// Default budget for one observer callback before `attachObserver`'s debug-mode watchdog warns
  /// about it. One 60 fps frame — the canonical "this just dropped a frame" line.
  static const defaultSlowCallbackThreshold = Duration(milliseconds: 16);

  /// Default (empty) header map used by [ProbeTarget] when no `headers` argument is provided.
  static const defaultProbeHeaders = <String, String>{};

  /// HTTP 200 (OK) status code. Defined locally because `dart:io.HttpStatus` is unavailable on the
  /// web platform — importing it would break web compilation despite the constant itself being trivial.
  static const httpStatusOk = 200;

  /// Public endpoints probed by `InternetConnection` when no custom target list is supplied. All
  /// answer HEAD with 200.
  ///
  /// All four resolve to Cloudflare and two allow long-lived caching, so pass your own `targets` if
  /// you need operator spread or strict no-cache.
  ///
  /// Safe to share because every layer is `const`: the list literal, each [ProbeTarget], and each
  /// [ConstUri] are compile-time canonical and reject mutation at runtime.
  static const defaultProbeTargets = <ProbeTarget>[
    ProbeTarget(uri: ConstUri('https://one.one.one.one')),
    ProbeTarget(uri: ConstUri('https://icanhazip.com')),
    ProbeTarget(uri: ConstUri('https://jsonplaceholder.typicode.com/todos/1')),
    ProbeTarget(uri: ConstUri('https://pokeapi.co/api/v2/ability/?limit=1')),
  ];
}

/// Consumer that accepts any single argument and returns void.
///
/// Drops into `void Function(T)` slots where the value is discarded — e.g. `Stream<X>` to
/// `Stream<void>` via `.map(noopWithVal)`, or an inert listener that just keeps a broadcast alive.
// Empty body is the point (no-op); a getter (not a top-level final) sidesteps
// `prefer_function_declarations_over_variables`.
// ignore: no-empty-block
void Function(Object?) get noopWithVal => (_) {};
