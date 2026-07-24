import 'dart:async';
import 'dart:io';

/// A configurable HTTP server on `127.0.0.1` for scenarios needing a real but deterministic transport —
/// exercises the `HttpProbe` path end-to-end without the noise of DNS, TLS, packet loss, or NAT.
/// Binds to port 0 (OS picks a free port); read [boundPort] after [start].
///
/// Runtime knobs:
///
/// * [setUp] / [setDown] — flip between responding [statusCode] and refusing with 503. Used by `flapping_network`.
/// * [latency] — artificial response delay, applied before responding.
/// * [statusCode] — the status returned when up. Defaults to 200.
///
/// No locking needed: Dart's single-threaded event loop means in-flight requests see a consistent
/// snapshot of these fields.
final class LocalHttpServer {
  HttpServer? _server;
  var _isUp = true;
  Duration _latency = Duration.zero;
  int _statusCode = HttpStatus.ok;
  var _requestCount = 0;

  /// The port the server is listening on. Throws if accessed before [start].
  int get boundPort {
    final server = _server;
    if (server == null) throw StateError('LocalHttpServer.start() not yet awaited');

    return server.port;
  }

  /// The base URI clients should target — `http://127.0.0.1:<port>`.
  /// Throws if accessed before [start].
  Uri get baseUri => Uri.parse('http://127.0.0.1:$boundPort');

  /// Total HTTP requests received since [start]. Reset on [stop].
  int get requestCount => _requestCount;

  Future<void> start() async {
    if (_server != null) throw StateError('already started');
    _requestCount = 0;
    _server = await HttpServer.bind('127.0.0.1', 0);
    unawaited(_serve());
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    // Note: `_requestCount` is NOT reset here — callers commonly read it after stop() for end-of-scenario
    // reporting. [start] resets if you reuse the same instance.
  }

  /// Server starts answering [statusCode] (default 200) again.
  void setUp() => _isUp = true;

  /// Server answers 503 to all requests until [setUp] is called again.
  void setDown() => _isUp = false;

  /// Toggles between up and down. Used by `flapping_network` on a timer.
  void toggle() => _isUp = !_isUp;

  // Write-only knob: scenarios push runtime config in; the current value never needs reading back.
  // ignore: avoid_setters_without_getters
  set latency(Duration value) => _latency = value;

  // Write-only knob — see [latency] above.
  // ignore: avoid_setters_without_getters
  set statusCode(int value) => _statusCode = value;

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;

    await for (final request in server) {
      _requestCount++;
      if (_latency > Duration.zero) await Future<void>.delayed(_latency);
      await (request.response..statusCode = _isUp ? _statusCode : HttpStatus.serviceUnavailable)
          .close();
    }
  }
}
