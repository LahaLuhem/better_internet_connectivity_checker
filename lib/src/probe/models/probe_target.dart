import 'package:http/http.dart' as http;

import '../../data/typedefs.dart';
import '../../data/values.dart';

/// A single internet-reachability target — what to probe and what counts as
/// success.
///
/// Targets are immutable value objects that carry the caller-controlled knobs
/// (URI, request timeout, headers, and the response-acceptance predicate).
/// Reuse them across instances; there is no per-call state.
final class ProbeTarget {
  /// The URI to probe.
  ///
  /// Make sure your endpoint disables HTTP caching (e.g. responds with
  /// `Cache-Control: no-cache`). A cached response will mask connectivity
  /// problems by short-circuiting the request locally.
  ///
  /// On the web platform the endpoint must allow CORS for the request to
  /// reach the probe.
  final Uri uri;

  /// Maximum time a single probe is allowed to take.
  final Duration timeout;

  /// Headers attached to the outbound probe request.
  final Map<String, String> headers;

  /// Predicate that maps an HTTP response to a success/failure decision.
  ///
  /// Adapt the probe to non-[Values.httpStatusOk] healthy endpoints by passing
  /// your own [ResponseAcceptor] (e.g. an API that pings with HTTP 204).
  final ResponseAcceptor isSuccess;

  /// Creates a [ProbeTarget].
  ///
  /// [uri] is the URL that will be probed. The probe implementation chooses
  /// the request method — the built-in HTTP HEAD probe uses HEAD.
  ///
  /// [timeout] caps the wait for a single probe. Defaults to
  /// [Values.defaultProbeTimeout] — short enough that a stalled probe does
  /// not dominate the surrounding check interval while still tolerating
  /// mobile-network latency.
  ///
  /// [headers] are sent verbatim with each request. Defaults to
  /// [Values.defaultProbeHeaders] (empty).
  ///
  /// [isSuccess] decides whether a response counts as a healthy endpoint.
  /// Defaults to "HTTP 200 exactly" — tighten or loosen as your endpoint
  /// requires (e.g. accept any 2xx).
  const ProbeTarget({
    required this.uri,
    this.timeout = Values.defaultProbeTimeout,
    this.headers = Values.defaultProbeHeaders,
    this.isSuccess = _statusIs200,
  });

  static bool _statusIs200(http.Response response) => response.statusCode == Values.httpStatusOk;
}
