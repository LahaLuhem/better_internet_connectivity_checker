import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// A [ConnectivityProbe] returning canned [ProbeResult]s with no network I/O — the only way to measure
/// µs-scale dispatch changes when a real probe takes 100–1000 ms.
///
/// Three modes:
///
/// * [FakeProbe.alwaysSuccess] — always succeeds with a fixed simulated response time (default 10 ms).
/// * [FakeProbe.alwaysFailure] — always fails, with a fixed response time and error.
/// * [FakeProbe.scripted] — serves a programmable list one result per call, cycling when exhausted.
///   Drives `flapping_network`-style scenarios.
///
/// "Simulated response time" is the value *reported* on the result, not a real delay — the call resolves
/// on the next microtask. For a real delay, use the localhost [`local_http_server.dart`](local_http_server.dart).
final class FakeProbe implements ConnectivityProbe {
  final _Mode _mode;
  final Duration _responseTime;
  final Object? _error;
  final List<ProbeResult>? _script;
  var _scriptIndex = 0;

  new alwaysSuccess({this._responseTime = const Duration(milliseconds: 10)})
    : _mode = _Mode.alwaysSuccess,
      _error = null,
      _script = null;

  new alwaysFailure({
    this._responseTime = const Duration(milliseconds: 10),
    Object this._error = 'fake failure',
  }) : _mode = .alwaysFailure,
       _script = null;

  new scripted(List<ProbeResult> script)
    : assert(script.isNotEmpty, 'scripted FakeProbe needs at least one result'),
      _mode = .scripted,
      _responseTime = .zero,
      _error = null,
      _script = List.unmodifiable(script);

  /// Number of probe calls served so far. Useful for assertions in tests and for sanity-checking scenario behaviour.
  int get callCount => _callCount;
  var _callCount = 0;

  @override
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal}) {
    _callCount++;

    return Future.syncValue(switch (_mode) {
      .alwaysSuccess => .success(target: target, responseTime: _responseTime),
      .alwaysFailure => .failure(target: target, responseTime: _responseTime, error: _error),
      .scripted => _nextScripted(target),
    });
  }

  ProbeResult _nextScripted(ProbeTarget target) {
    final result = _script![_scriptIndex];
    _scriptIndex = (_scriptIndex + 1) % _script.length;

    // Rebind the target — the scripted result was likely built with a placeholder target, but the
    // scheduler passes its configured target in.
    return result.isSuccess
        ? .success(target: target, responseTime: result.responseTime)
        : .failure(target: target, responseTime: result.responseTime, error: result.error);
  }
}

enum _Mode { alwaysSuccess, alwaysFailure, scripted }
