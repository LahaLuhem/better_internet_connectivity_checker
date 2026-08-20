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

  /// Maximum time a single probe is allowed to take.
  ///
  /// Defaults to [Values.defaultProbeTimeout] — short enough that a stalled probe doesn't dominate
  /// the check interval, long enough for mobile-network latency.
  final Duration timeout = Values.defaultProbeTimeout,

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
      'headers: $headers'
      ')';

  static bool _statusIs200(http.Response response) => response.statusCode == Values.httpStatusOk;
}
