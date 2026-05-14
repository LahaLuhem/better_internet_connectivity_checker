import 'dart:async';

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
///
/// The probe issues an [http.AbortableRequest] so that the underlying socket
/// is closed when the per-target deadline expires or when the policy's
/// `cancelSignal` fires (e.g. a sibling probe wins under
/// `AnyReachablePolicy`). Clients that honour [http.Abortable] — the native
/// `IOClient` and the web `BrowserClient` — abort at the transport layer;
/// clients that do not (notably `MockClient`) silently fall through to a
/// normal completion.
final class HttpHeadProbe implements ConnectivityProbe {
  final http.Client _client;

  /// Creates an [HttpHeadProbe], optionally wrapping a caller-supplied
  /// [http.Client].
  HttpHeadProbe({http.Client? client}) : _client = client ?? http.Client();

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
      final request = http.AbortableRequest('HEAD', target.uri, abortTrigger: abortCompleter.future)
        ..headers.addAll(target.headers);
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
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
