import 'dart:async';

import 'package:http/http.dart' as http;

import '../connectivity_probe.dart';
import '../models/probe_result.dart';
import '../models/probe_target.dart';

/// Fires off an HTTP request and reads the response status as the answer.
///
/// [HttpProbe.head] is the default and the cheapest request HTTP has. Fall back to [HttpProbe.get]
/// for endpoints that 405 on HEAD or strip its caching headers. Why HTTP rather than DNS or TCP:
/// [Appendix](https://github.com/LahaLuhem/better_internet_connectivity_checker/blob/main/APPENDIX.md#why-http-head-default-probe).
///
/// Pass your own [http.Client] for middleware, proxies or mocks, and close that one yourself. The
/// default client belongs to this probe.
///
/// Requests go out as [http.AbortableRequest], so the socket really does close on timeout or when a
/// sibling probe wins the race. Clients that skip [http.Abortable], `MockClient` most notably, run
/// to completion instead. See [Appendix](https://github.com/LahaLuhem/better_internet_connectivity_checker/blob/main/APPENDIX.md#probe-cancellation-via-http-abortable).
final class HttpProbe._(final String _method, http.Client? client) implements ConnectivityProbe {
  final http.Client _client = client ?? http.Client();

  /// Creates an [HttpProbe] that issues HEAD.
  new head({http.Client? client}) : this._('HEAD', client);

  /// Creates an [HttpProbe] that issues GET. The body is drained off the wire but never held in
  /// memory, so `isSuccess` always sees an empty one.
  new get({http.Client? client}) : this._('GET', client);

  @override
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal}) async {
    final stopwatch = Stopwatch()..start();
    final abortCompleter = Completer<void>();
    unawaited(cancelSignal?.whenComplete(abortCompleter.complete));

    try {
      final request =
          http.AbortableRequest(_method, target.uri, abortTrigger: abortCompleter.future)
            ..followRedirects = target.followRedirects
            ..headers.addAll(target.headers);
      final streamedResponse = await _client.send(request);
      await streamedResponse.stream.drain<void>();
      final response = http.Response.bytes(
        const [],
        streamedResponse.statusCode,
        request: streamedResponse.request,
        headers: streamedResponse.headers,
        isRedirect: streamedResponse.isRedirect,
        persistentConnection: streamedResponse.persistentConnection,
        reasonPhrase: streamedResponse.reasonPhrase,
      );
      stopwatch.stop();

      return target.isSuccess(response)
          ? .success(target: target, responseTime: stopwatch.elapsed)
          : .failure(target: target, responseTime: stopwatch.elapsed);
    } on Exception catch (error) {
      stopwatch.stop();

      return .failure(target: target, responseTime: stopwatch.elapsed, error: error);
    }
  }
}
