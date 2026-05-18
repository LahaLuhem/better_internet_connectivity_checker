import 'dart:async';

import 'package:http/http.dart' as http;

import '../connectivity_probe.dart';
import '../models/probe_result.dart';
import '../models/probe_target.dart';

/// A [ConnectivityProbe] that performs an HTTP request and treats the
/// response status as the reachability signal.
///
/// Pick the request method via the named constructor:
///
/// - [HttpProbe.head] is the default. HEAD is the cheapest probe HTTP
///   exposes: servers respond without a body, so it minimises bandwidth and
///   latency. Most reliability endpoints support it.
/// - [HttpProbe.get] is the fallback when an endpoint returns HTTP 405 for
///   HEAD, strips caching headers on HEAD, or otherwise misbehaves under it.
///   The response body is consumed from the wire but not buffered into
///   memory, so a verbose endpoint does not bloat the probe's footprint —
///   any `isSuccess` predicate sees an empty `response.body` regardless of
///   what the server sent.
///
/// Pass a custom [http.Client] to inject middleware, set proxies, or use
/// a `MockClient` in tests. The default client is owned by this probe; close
/// it via [http.Client.close] only if you constructed it yourself.
///
/// The probe issues an [http.AbortableRequest] so that the underlying socket
/// is closed when the per-target deadline expires or when the policy's
/// `cancelSignal` fires (e.g. a sibling probe wins under
/// `AnyReachablePolicy`). Clients that honour [http.Abortable] — the native
/// `IOClient` and the web `BrowserClient` — abort at the transport layer;
/// clients that do not (notably `MockClient`) silently fall through to a
/// normal completion.
final class HttpProbe implements ConnectivityProbe {
  final String _method;
  final http.Client _client;

  /// Creates an [HttpProbe] that issues HTTP HEAD requests.
  HttpProbe.head({http.Client? client}) : this._('HEAD', client);

  /// Creates an [HttpProbe] that issues HTTP GET requests. The response body
  /// is drained from the wire but not loaded into memory.
  HttpProbe.get({http.Client? client}) : this._('GET', client);

  HttpProbe._(this._method, http.Client? client) : _client = client ?? http.Client();

  @override
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal}) async {
    final stopwatch = Stopwatch()..start();
    final abortCompleter = Completer<void>();
    void triggerAbort() {
      if (!abortCompleter.isCompleted) abortCompleter.complete();
    }

    final timeoutTimer = Timer(target.timeout, triggerAbort);
    unawaited(cancelSignal?.whenComplete(triggerAbort));

    try {
      final request = http.AbortableRequest(
        _method,
        target.uri,
        abortTrigger: abortCompleter.future,
      )..headers.addAll(target.headers);
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
    } finally {
      timeoutTimer.cancel();
    }
  }
}
