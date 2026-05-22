import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// A [ConnectivityProbe] that returns canned [ProbeResult]s without any
/// network I/O. Lets micro-benchmarks isolate coordinator overhead from
/// transport cost — which is the only way to measure µs-scale dispatch
/// changes when a real probe takes 100–1000 ms.
///
/// Three modes:
///
/// * [FakeProbe.alwaysSuccess] — every call returns a success with the same
///   simulated response time. Default response time is 10 ms.
/// * [FakeProbe.alwaysFailure] — every call returns a failure with the same
///   simulated response time + a fixed error object.
/// * [FakeProbe.scripted] — consumes a programmable list of `ProbeResult`s,
///   one per call, cycling back to the start when exhausted. Useful for
///   driving `flapping_network`-style scenarios.
///
/// "Simulated response time" is the value reported on the [ProbeResult], NOT
/// a real delay. The probe call resolves on the next microtask. Scenarios
/// that need a real delay should use `dart:io`'s `HttpServer` on localhost
/// (see [`local_http_server.dart`](local_http_server.dart)).
final class FakeProbe implements ConnectivityProbe {
  final _Mode _mode;
  final Duration _responseTime;
  final Object? _error;
  final List<ProbeResult>? _script;
  var _scriptIndex = 0;

  FakeProbe.alwaysSuccess({Duration responseTime = const Duration(milliseconds: 10)})
    : _mode = _Mode.alwaysSuccess,
      _responseTime = responseTime,
      _error = null,
      _script = null;

  FakeProbe.alwaysFailure({
    Duration responseTime = const Duration(milliseconds: 10),
    Object error = 'fake failure',
  }) : _mode = _Mode.alwaysFailure,
       _responseTime = responseTime,
       _error = error,
       _script = null;

  FakeProbe.scripted(List<ProbeResult> script)
    : assert(script.isNotEmpty, 'scripted FakeProbe needs at least one result'),
      _mode = _Mode.scripted,
      _responseTime = Duration.zero,
      _error = null,
      _script = List.unmodifiable(script);

  /// Number of probe calls served so far. Useful for assertions in tests
  /// and for sanity-checking scenario behaviour.
  int get callCount => _callCount;
  var _callCount = 0;

  @override
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal}) {
    _callCount++;

    return switch (_mode) {
      _Mode.alwaysSuccess => Future.value(
        ProbeResult.success(target: target, responseTime: _responseTime),
      ),
      _Mode.alwaysFailure => Future.value(
        ProbeResult.failure(target: target, responseTime: _responseTime, error: _error),
      ),
      _Mode.scripted => Future.value(_nextScripted(target)),
    };
  }

  ProbeResult _nextScripted(ProbeTarget target) {
    final result = _script![_scriptIndex];
    _scriptIndex = (_scriptIndex + 1) % _script.length;

    // Rebind the target — the scripted result was likely built with a
    // placeholder target, but the scheduler passes its configured target in.
    return result.isSuccess
        ? ProbeResult.success(target: target, responseTime: result.responseTime)
        : ProbeResult.failure(
            target: target,
            responseTime: result.responseTime,
            error: result.error,
          );
  }
}

enum _Mode { alwaysSuccess, alwaysFailure, scripted }
