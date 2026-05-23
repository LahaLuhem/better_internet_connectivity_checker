// Omitted from coverage via `lcov --remove '*/printing_connectivity_observer.dart'`
// in `.github/workflows/package.yml`. Pure delegation to `dart:developer`'s
// `log()` sink — every method is a single-line forwarder with no branching,
// no state, and no side effect we own. `developer.log` has no first-class
// test seam (no Stream of records to assert against), so unit-testing would
// either capture VM-service events (heavy, brittle) or assert "didn't throw"
// (no signal). Matches the principle applied in `benchmark/python/`'s
// `[tool.coverage.run] omit`: smoke-only files don't contribute to either
// side of the ratio. When adding another smoke-only file, append a matching
// `--remove` glob to the workflow step.

import 'dart:developer' as developer;

import '../../status/internet_status.dart';
import '../connectivity_observer.dart';

/// A [ConnectivityObserver] that writes every event to
/// [developer.log] under a configurable logger name.
///
/// Chosen over `print()` so the package stays compliant with
/// `avoid_print` (a project-wide lint) and integrates with Flutter
/// DevTools' logging view out of the box. In a plain-Dart context
/// (CLI, server, web) [developer.log] still surfaces via stdout —
/// callers wanting structured sinks should subclass
/// [ConnectivityObserver] directly instead.
///
/// {@macro connectivity_observer_threading}
final class PrintingConnectivityObserver extends ConnectivityObserver {
  /// Default logger name used for every emitted record.
  static const _defaultName = 'better_internet_connectivity_checker';

  /// Severity level forwarded to [developer.log] for trigger errors —
  /// matches `Level.SEVERE` from `package:logging`'s scale so consumers
  /// piping through `package:logging` see the record at the expected
  /// severity.
  static const _severeLevel = 900;

  final String _name;

  /// Creates a [PrintingConnectivityObserver].
  ///
  /// [name] is forwarded to [developer.log]'s `name:` argument; it shows up
  /// as the source channel in DevTools and lets consumers filter records
  /// from this package distinctly from their own logging.
  const PrintingConnectivityObserver({String name = _defaultName}) : _name = name;

  @override
  void onStatusChangeEmitted(InternetStatus? previous, InternetStatus next) =>
      developer.log('status emitted: ${previous ?? '<none>'} -> $next', name: _name);

  @override
  void onCheckCompleted(InternetStatus result) =>
      developer.log('check completed: $result', name: _name);

  @override
  void onExternalTriggerFired() => developer.log('external recheck trigger fired', name: _name);

  @override
  void onExternalTriggerError(Object error, StackTrace stackTrace) => developer.log(
    'external recheck trigger error',
    name: _name,
    error: error,
    stackTrace: stackTrace,
    level: _severeLevel,
  );

  @override
  void onCheckIntervalChanged(Duration previous, Duration next) =>
      developer.log('check interval changed: $previous -> $next', name: _name);

  @override
  void onSlowThresholdChanged(Duration? previous, Duration? next) => developer.log(
    'slow threshold changed: ${previous ?? '<disabled>'} -> ${next ?? '<disabled>'}',
    name: _name,
  );

  @override
  void onDispose() => developer.log('checker disposed', name: _name);
}
