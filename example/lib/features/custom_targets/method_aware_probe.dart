import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:http/http.dart' as http;

import 'data/enums/probe_method.dart';

/// Inline [ConnectivityProbe] that dispatches HEAD or GET based on a
/// configured [probeMethod], and surfaces the response's `Allow` header (when
/// present) via [onAllowHeader]. Demonstrates the pluggable probe seam —
/// the package's built-in [HttpHeadProbe] only does HEAD, and
/// [ProbeResult] is intentionally protocol-agnostic, so HTTP-specific data
/// is surfaced on the probe itself rather than on the result.
///
/// Also demonstrates honouring [ConnectivityProbe.probe]'s `cancelSignal`
/// via [http.AbortableRequest]: a single abort completer is fed by both the
/// per-target timeout and the policy-supplied signal, so the in-flight
/// request is released at the transport layer the moment either fires.
final class MethodAwareProbe implements ConnectivityProbe {
  final ProbeMethod probeMethod;
  final void Function(String allow)? onAllowHeader;
  final http.Client _client;

  MethodAwareProbe({required this.probeMethod, this.onAllowHeader, http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal}) async {
    final stopwatch = Stopwatch()..start();
    final abortCompleter = Completer<void>();
    void triggerAbort() {
      if (!abortCompleter.isCompleted) abortCompleter.complete();
    }

    final timeoutTimer = Timer(target.timeout, triggerAbort);
    unawaited(cancelSignal?.whenComplete(triggerAbort));

    final httpMethod = switch (probeMethod) {
      .head => 'HEAD',
      .get => 'GET',
    };

    try {
      final request = http.AbortableRequest(
        httpMethod,
        target.uri,
        abortTrigger: abortCompleter.future,
      )..headers.addAll(target.headers);
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      stopwatch.stop();

      if (target.isSuccess(response)) {
        return .success(target: target, responseTime: stopwatch.elapsed);
      }

      final allow = response.headers['allow'] ?? response.headers['Allow'];
      if (allow != null && allow.isNotEmpty) onAllowHeader?.call(allow);

      return .failure(target: target, responseTime: stopwatch.elapsed);
    } on Exception catch (error) {
      stopwatch.stop();

      return .failure(target: target, responseTime: stopwatch.elapsed, error: error);
    } finally {
      timeoutTimer.cancel();
    }
  }
}
