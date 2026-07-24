// Omitted from coverage via `lcov --remove '*/printing_connectivity_observer.dart'` in
// `.github/workflows/package.yml`: every method is a single-line forwarder to `dart:developer`'s
// `log()` with no branching or state, and `developer.log` has no test seam
// (testing it would capture VM-service events or assert "didn't throw" — no signal). Same principle
// as `benchmark/python/`'s `[tool.coverage.run] omit`. Adding another smoke-only file? Append a
// matching `--remove` glob to the workflow step.

import 'dart:developer' as developer;

import '../../status/internet_status.dart';
import '../connectivity_observer.dart';

/// A [ConnectivityObserver] that writes every event to [developer.log] under a configurable name.
///
/// Chosen over `print()` to stay `avoid_print`-compliant and integrate with Flutter DevTools' logging view.
/// In plain Dart (CLI, server, web) [developer.log] still surfaces via stdout.
/// Callers wanting a structured sink should subclass [ConnectivityObserver] directly.
///
/// {@macro connectivity_observer_threading}
final class PrintingConnectivityObserver extends ConnectivityObserver {
  /// Default logger name used for every emitted record.
  static const _defaultName = 'better_internet_connectivity_checker';

  /// Severity forwarded to [developer.log] for trigger errors — `package:logging`'s `Level.SEVERE`,
  /// so consumers piping through `package:logging` see the expected severity.
  static const _severeLevel = 900;

  final String _name;

  /// Creates a [PrintingConnectivityObserver].
  ///
  /// [_name] is forwarded to [developer.log]'s `name:` — the DevTools source channel, letting consumers
  /// filter this package's records from their own.
  const PrintingConnectivityObserver({this._name = _defaultName});

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
