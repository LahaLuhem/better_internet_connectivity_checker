import '../probe/models/probe_target.dart';

/// Internal default values for the package's own classes.
///
/// Grouped in an `abstract final` class so call sites read `Values.defaultX`
/// — the prefix makes the origin obvious without re-reading imports. Not
/// exported from the public API; consumers configure these via constructor
/// arguments instead of reaching for them directly.
abstract final class Values {
  /// Default periodic check interval used by `InternetConnection` when no
  /// `checkInterval` argument is provided.
  static const defaultCheckInterval = Duration(seconds: 10);

  /// Default per-probe timeout used by [ProbeTarget] when no `timeout`
  /// argument is provided.
  static const defaultProbeTimeout = Duration(seconds: 3);

  /// Default (empty) header map used by [ProbeTarget] when no `headers`
  /// argument is provided.
  static const defaultProbeHeaders = <String, String>{};

  /// HTTP 200 (OK) status code. Defined locally because `dart:io.HttpStatus`
  /// is unavailable on the web platform — importing it would break web
  /// compilation despite the constant itself being trivial.
  static const httpStatusOk = 200;

  /// Curated reliability endpoints probed by `InternetConnection` when no
  /// custom target list is supplied. Chosen for operator diversity and low
  /// cache surface.
  ///
  /// Safe to share because [List.unmodifiable] prevents mutation.
  static final defaultProbeTargets = List<ProbeTarget>.unmodifiable([
    ProbeTarget(uri: Uri.parse('https://one.one.one.one')),
    ProbeTarget(uri: Uri.parse('https://icanhazip.com/')),
    ProbeTarget(uri: Uri.parse('https://jsonplaceholder.typicode.com/todos/1')),
    ProbeTarget(uri: Uri.parse('https://pokeapi.co/api/v2/ability/?limit=1')),
  ]);
}

/// Consumer that accepts any single argument and returns void.
///
/// Drops into `void Function(T)` parameter slots where the value should be
/// discarded — e.g. converting `Stream<X>` to `Stream<void>` via
/// `.map(noopWithVal)`, or providing an inert listener for a stream whose
/// only purpose is to keep a broadcast source alive.
// Empty body is the whole point (no-op consumer); getter (not top-level
// final) sidesteps `prefer_function_declarations_over_variables`.
// ignore: no-empty-block
void Function(Object?) get noopWithVal => (_) {};
