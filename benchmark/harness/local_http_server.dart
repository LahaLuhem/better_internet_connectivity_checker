import 'dart:async';
import 'dart:io';

import 'package:minted_network/minted_network.dart';

/// Loopback address the server binds to. Parsed once so the literal isn't written out twice. The
/// bang is the `int.parse('42')` case: an author-controlled literal.
final _loopback = IpAddress.tryParse('127.0.0.1')!;

/// An HTTP server on `127.0.0.1`, so scenarios get a real transport without DNS, TLS, packet loss or
/// NAT muddying the numbers. Binds to port 0, and you read [boundPort] after [start].
///
/// [setUp] and [setDown] flip it between [statusCode] and a 503, [latency] adds an artificial delay.
/// No locking needed, since one event loop means in-flight requests see a consistent snapshot.
final class LocalHttpServer {
  HttpServer? _server;
  var _isUp = true;
  Duration _latency = .zero;
  int _statusCode = HttpStatus.ok;
  var _requestCount = 0;

  /// The port it's listening on. Throws before [start], where the `-1` sentinel gets turned down by
  /// [Port.tryFrom] along with anything else out of range, so one branch covers both.
  Port get boundPort {
    final port = Port.tryFrom(_server?.port ?? -1);
    if (port == null) throw StateError('LocalHttpServer.start() not yet awaited');

    return port;
  }

  /// What clients should target, `http://127.0.0.1:<port>`. Throws before [start].
  Uri get baseUri => Uri.http('${_loopback.value}:${boundPort.value}');

  /// Total HTTP requests received since [start]. Reset on [stop].
  int get requestCount => _requestCount;

  Future<void> start() async {
    if (_server != null) throw StateError('already started');
    _requestCount = 0;
    _server = await HttpServer.bind(_loopback.value, 0);
    unawaited(_serve());
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    // `_requestCount` is NOT reset here, because callers commonly read it after stop() for end-of-scenario
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

  // Write-only knob, see [latency] above.
  // ignore: avoid_setters_without_getters
  set statusCode(int value) => _statusCode = value;

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;

    await for (final request in server) {
      _requestCount++;
      if (_latency > .zero) await Future<void>.delayed(_latency);
      await (request.response..statusCode = _isUp ? _statusCode : HttpStatus.serviceUnavailable)
          .close();
    }
  }
}
