import 'package:http/http.dart' as http;

import '../connectivity_probe.dart';
import '../models/probe_result.dart';
import '../models/probe_target.dart';

/// A [ConnectivityProbe] that performs an HTTP HEAD request.
///
/// HEAD is preferred over GET because servers can respond without a body —
/// less data on the wire, less latency, less load on the endpoint. Most
/// reliability endpoints support HEAD.
///
/// Pass a custom [http.Client] to inject middleware, set proxies, or use
/// a `MockClient` in tests. The default client is owned by this probe; close
/// it via [http.Client.close] only if you constructed it yourself.
final class HttpHeadProbe implements ConnectivityProbe {
  /// Creates an [HttpHeadProbe], optionally wrapping a caller-supplied
  /// [http.Client].
  HttpHeadProbe({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<ProbeResult> probe(ProbeTarget target) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client
          .head(target.uri, headers: target.headers)
          .timeout(target.timeout);
      stopwatch.stop();

      return target.isSuccess(response)
          ? ProbeResult.success(target: target, responseTime: stopwatch.elapsed)
          : ProbeResult.failure(target: target, responseTime: stopwatch.elapsed);
    } on Exception catch (error) {
      stopwatch.stop();

      return ProbeResult.failure(target: target, responseTime: stopwatch.elapsed, error: error);
    }
  }
}
