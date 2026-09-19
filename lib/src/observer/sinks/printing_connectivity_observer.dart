// Dropped from coverage by an `lcov --remove` glob in `.github/workflows/package.yml`: every method
// is a one-line forward to `developer.log`, which has no test seam. Adding another smoke-only file?
// Add a matching glob there.

import 'dart:developer' as developer;

import '../../status/internet_status.dart';
import '../connectivity_observer.dart';

/// Writes every event to [developer.log], which turns up in DevTools' logging view and on stdout
/// everywhere else. Want something structured? Subclass [ConnectivityObserver] yourself.
///
/// {@macro connectivity_observer_threading}
final class const PrintingConnectivityObserver({
  /// Goes to [developer.log]'s `name:`, so you can filter this package's records out from your own.
  final String _name = _defaultName,
}) extends ConnectivityObserver {
  static const _defaultName = 'better_internet_connectivity_checker';

  /// Severity passed to [developer.log] for trigger errors.
  static const _severeLevel = 900;

  /// Creates a [PrintingConnectivityObserver].
  this;

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
