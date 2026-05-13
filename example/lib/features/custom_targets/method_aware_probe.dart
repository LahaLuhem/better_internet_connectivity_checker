import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:http/http.dart' as http;

import 'data/enums/probe_method.dart';

/// Inline [ConnectivityProbe] that dispatches HEAD or GET based on a
/// configured [probeMethod], and surfaces the response's `Allow` header (when
/// present) via [onAllowHeader]. Demonstrates the pluggable probe seam —
/// the package's built-in [HttpHeadProbe] only does HEAD, and
/// [ProbeResult] is intentionally protocol-agnostic, so HTTP-specific data
/// is surfaced on the probe itself rather than on the result.
final class MethodAwareProbe implements ConnectivityProbe {
  final ProbeMethod probeMethod;
  final void Function(String allow)? onAllowHeader;
  final http.Client _client;

  MethodAwareProbe({required this.probeMethod, this.onAllowHeader, http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<ProbeResult> probe(ProbeTarget target) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await switch (probeMethod) {
        .head => _client.head(target.uri, headers: target.headers).timeout(target.timeout),
        .get => _client.get(target.uri, headers: target.headers).timeout(target.timeout),
      };
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
    }
  }
}
