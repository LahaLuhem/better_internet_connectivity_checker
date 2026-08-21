import 'package:http/http.dart' as http;

import '../../data/typedefs.dart';
import '../../data/values.dart';

/// A single internet-reachability target — what to probe and what counts as success.
///
/// Immutable value object carrying the caller-controlled knobs (URI, timeout, headers, and the response-acceptance predicate).
/// Reuse across instances; there's no per-call state.
final class const ProbeTarget({
  /// The URI to probe.
  ///
  /// Ensure the endpoint disables HTTP caching (e.g. `Cache-Control: no-cache`); a cached response
  /// masks connectivity problems by short-circuiting locally. On the web the endpoint must allow
  /// CORS for the request to reach the probe.
  required final Uri uri,

  /// Cap on one probe of this target, kept by `InternetConnection` rather than by the probe itself.
  ///
  /// Covers the whole probe call, so a probe that retries internally has to fit every attempt inside
  /// it. Defaults to [Values.defaultProbeTimeout], short enough that a stalled probe doesn't dominate
  /// the check interval and long enough for mobile-network latency.
  final Duration timeout = Values.defaultProbeTimeout,

  /// Whether a `3xx` response should be followed. Defaults to false, since a redirect is what a
  /// captive portal serves and following it would report the login page as reachable. Native clients
  /// hand the `3xx` to [isSuccess], the web throws instead, and both land as a failure.
  final bool followRedirects = false,

  /// Headers attached to the outbound probe request. Sent verbatim.
  final Map<String, String> headers = Values.defaultProbeHeaders,

  /// Predicate mapping an HTTP response to a success/failure decision.
  ///
  /// Defaults to "HTTP 200 exactly". Pass your own [ResponseAcceptor] for endpoints healthy on a
  /// non-[Values.httpStatusOk] status (e.g. an API that pings with HTTP 204).
  final ResponseAcceptor isSuccess = _statusIs200,
}) {
  /// Creates a [ProbeTarget] probed with whatever method the probe chooses (the built-in uses HEAD).
  this;

  @override
  String toString() =>
      'ProbeTarget('
      'uri: $uri, '
      'timeout: $timeout, '
      'followRedirects: $followRedirects, '
      'headers: $headers'
      ')';

  static bool _statusIs200(http.Response response) => response.statusCode == Values.httpStatusOk;
}
