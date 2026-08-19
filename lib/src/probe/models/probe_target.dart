import 'package:http/http.dart' as http;

import '../../data/typedefs.dart';
import '../../data/values.dart';

/// A single internet-reachability target — what to probe and what counts as success.
///
/// Immutable value object carrying the caller-controlled knobs (URI, timeout, headers, and the response-acceptance predicate).
/// Reuse across instances; there's no per-call state.
final class ProbeTarget {
  /// The URI to probe.
  ///
  /// Ensure the endpoint disables HTTP caching (e.g. `Cache-Control: no-cache`); a cached response
  /// masks connectivity problems by short-circuiting locally. On the web the endpoint must allow
  /// CORS for the request to reach the probe.
  final Uri uri;

  /// Maximum time a single probe is allowed to take.
  final Duration timeout;

  /// Headers attached to the outbound probe request.
  final Map<String, String> headers;

  /// Predicate mapping an HTTP response to a success/failure decision.
  ///
  /// Pass your own [ResponseAcceptor] for endpoints healthy on a non-[Values.httpStatusOk] status
  /// (e.g. an API that pings with HTTP 204).
  final ResponseAcceptor isSuccess;

  /// Creates a [ProbeTarget].
  ///
  /// [uri] is probed with the method the probe chooses (the built-in probe uses HEAD).
  ///
  /// [timeout] caps a single probe. Defaults to [Values.defaultProbeTimeout] — short enough that a
  /// stalled probe doesn't dominate the check interval, long enough for mobile-network latency.
  ///
  /// [headers] are sent verbatim. Defaults to [Values.defaultProbeHeaders] (empty).
  ///
  /// [isSuccess] decides whether a response is healthy. Defaults to "HTTP 200 exactly"; tighten or
  /// loosen as needed (e.g. accept any 2xx).
  const new({
    required this.uri,
    this.timeout = Values.defaultProbeTimeout,
    this.headers = Values.defaultProbeHeaders,
    this.isSuccess = _statusIs200,
  });

  @override
  String toString() =>
      'ProbeTarget('
      'uri: $uri, '
      'timeout: $timeout, '
      'headers: $headers'
      ')';

  static bool _statusIs200(http.Response response) => response.statusCode == Values.httpStatusOk;
}
