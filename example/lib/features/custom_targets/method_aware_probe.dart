import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:http/http.dart' as http;

/// Fires one request with [httpMethod] and hands the response's `Allow` header to [onAllowHeader].
///
/// Shows the one thing [HttpProbe] can't: [ProbeResult] carries no HTTP-specific fields, so anything
/// protocol-shaped has to hang off the probe instead. See [Appendix](https://github.com/LahaLuhem/better_internet_connectivity_checker/blob/main/APPENDIX.md#no-response-data-on-result).
///
/// Deliberately bare. `cancelSignal` is ignored, since this only runs on the failure-inspection path
/// and never inside a policy fan-out, so there's no sibling to race. It does keep the timeout itself,
/// because it's called directly rather than through [InternetConnection].
final class MethodAwareProbe implements ConnectivityProbe {
  final String httpMethod;
  final void Function(String allow)? onAllowHeader;
  final http.Client _client;

  new({required this.httpMethod, this.onAllowHeader, http.Client? client})
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
