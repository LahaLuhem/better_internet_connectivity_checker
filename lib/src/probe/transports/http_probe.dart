import 'dart:async';

import 'package:http/http.dart' as http;

import '../connectivity_probe.dart';
import '../models/probe_result.dart';
import '../models/probe_target.dart';

/// A [ConnectivityProbe] that performs an HTTP request and treats the response status as the reachability
/// signal.
///
/// Pick the request method via the named constructor:
///
/// - [HttpProbe.head] (default) — HEAD is the cheapest probe HTTP exposes (no response body, so minimal bandwidth and latency),
///   and most reliability endpoints support it.
/// - [HttpProbe.get] — the fallback for endpoints that return 405 for HEAD, strip caching headers
///   on it, or otherwise misbehave. The body is drained from the wire but never buffered, so a
///   verbose endpoint doesn't bloat the probe; `isSuccess` always sees an empty `response.body`.
///
/// Pass a custom [http.Client] to inject middleware, set proxies, or mock in tests. The default
/// client is owned by this probe. Close a client via [http.Client.close] only if you made it.
///
/// The probe issues an [http.AbortableRequest], so the socket closes when the per-target deadline
/// expires or the policy's `cancelSignal` fires (e.g. a sibling wins under `AnyReachablePolicy`).
/// Clients honouring [http.Abortable] — native `IOClient`, web `BrowserClient` — abort at the
/// transport layer; those that don't (notably `MockClient`) fall through to normal completion.
final class HttpProbe implements ConnectivityProbe {
  final String _method;
  final http.Client _client;

  /// Creates an [HttpProbe] that issues HTTP HEAD requests.
  HttpProbe.head({http.Client? client}) : this._('HEAD', client);

  /// Creates an [HttpProbe] that issues HTTP GET requests. The response body is drained from the wire
  /// but not loaded into memory.
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
