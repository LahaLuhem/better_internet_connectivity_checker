import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:http/http.dart' as http;

/// Inline [ConnectivityProbe] that fires one HTTP request with [httpMethod]
/// and surfaces the response's `Allow` header (when present) via
/// [onAllowHeader]. Demonstrates the *only* lesson the built-in [HttpProbe]
/// cannot teach: [ProbeResult] is intentionally protocol-agnostic, so
/// HTTP-specific data (status codes, headers, …) has to be exposed on the
/// probe itself — not on the shared result. See APPENDIX
/// `#no-response-data-on-result` for the rationale.
///
/// Intentionally minimal: the per-target timeout is honoured via
/// `Future.timeout`, and `cancelSignal` is accepted (interface contract) but
/// ignored — this probe only runs on the failure-inspection path, never
/// inside a policy fan-out, so there is no sibling probe to race against.
/// The library's [HttpProbe] is the reference implementation for full
/// transport-layer abort handling.
final class MethodAwareProbe implements ConnectivityProbe {
  final String httpMethod;
  final void Function(String allow)? onAllowHeader;
  final http.Client _client;

  MethodAwareProbe({required this.httpMethod, this.onAllowHeader, http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal}) async {
    final stopwatch = Stopwatch()..start();

    try {
      final request = http.Request(httpMethod, target.uri)..headers.addAll(target.headers);
      final streamedResponse = await _client.send(request).timeout(target.timeout);
      final response = await http.Response.fromStream(streamedResponse);
      stopwatch.stop();

      final allow = response.headers['allow'];
      if (allow != null && allow.isNotEmpty) onAllowHeader?.call(allow);

      return target.isSuccess(response)
          ? .success(target: target, responseTime: stopwatch.elapsed)
          : .failure(target: target, responseTime: stopwatch.elapsed);
    } on Exception catch (error) {
      stopwatch.stop();

      return .failure(target: target, responseTime: stopwatch.elapsed, error: error);
    }
  }
}
