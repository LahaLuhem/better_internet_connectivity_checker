import 'package:http/http.dart' as http;

/// Predicate run on an HTTP response to decide whether the probe succeeded.
typedef ResponseAcceptor = bool Function(http.Response response);

/// Jitter noise in `[0, 1)`, like `Random.nextDouble`. Injectable so a test can pin the draw.
typedef JitterSource = double Function();
