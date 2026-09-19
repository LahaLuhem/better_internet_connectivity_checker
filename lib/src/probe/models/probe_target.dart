import 'package:http/http.dart' as http;

import '../../data/typedefs.dart';
import '../../data/values.dart';

/// One thing to probe, plus what counts as success. No per-call state, so reuse them freely.
final class const ProbeTarget({
  /// Where to probe. Pick an endpoint that turns caching off, or a cached response answers locally
  /// and hides a real outage. On the web it has to allow CORS too.
  required final Uri uri,

  /// Cap on one probe of this target, covering the whole call, so a probe that retries has to fit
  /// every attempt inside it.
  ///
  /// It bounds the waiting, not the socket. A connect nobody answers hangs about until the OS reaps
  /// it, and only `HttpClient.connectionTimeout` on your own client shortens that.
  final Duration timeout = Values.defaultProbeTimeout,

  /// Follow a `3xx`? Off by default, because that redirect is usually a captive portal's login page,
  /// and following it would call the portal "online". See [Appendix](https://github.com/LahaLuhem/better_internet_connectivity_checker/blob/main/APPENDIX.md#what-portal-detection-rests-on).
  final bool followRedirects = false,

  /// Headers on the outgoing request, sent as-is.
  final Map<String, String> headers = Values.defaultProbeHeaders,

  /// Decides whether a response counts as success. Defaults to exactly HTTP 200, so pass your own
  /// [ResponseAcceptor] for an endpoint that pings with, say, a 204.
  final ResponseAcceptor isSuccess = _statusIs200,
}) {
  /// Creates a [ProbeTarget]. The probe picks the method, and the built-in one uses HEAD.
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
