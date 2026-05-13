import 'package:http/http.dart' as http;

/// Predicate run on an HTTP response to decide whether the probe succeeded.
typedef ResponseAcceptor = bool Function(http.Response response);
