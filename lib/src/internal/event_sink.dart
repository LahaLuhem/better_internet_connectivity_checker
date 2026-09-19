part of '../internet_connection.dart';

/// Fans [ConnectivityEvent]s out to a broadcast stream, one microtask at a time so a slow subscriber
/// can't stall the caller.
///
/// The controller is only built on the first read of [stream], so anyone who just watches
/// `onStatusChange` never pays for one. See [Appendix](https://github.com/LahaLuhem/better_internet_connectivity_checker/blob/main/APPENDIX.md#why-events-microtask-deferred).
final class _EventSink {
  // The analyser can't follow the `??=` in `stream` through to the `close()` in `dispose`.
  // ignore: close_sinks
  StreamController<ConnectivityEvent>? _controller;
  var _disposed = false;

  /// The event stream. The first read builds the controller. After [dispose] you get an empty stream
  /// that's already done, rather than a fresh controller.
  Stream<ConnectivityEvent> get stream {
    if (_disposed) return const Stream<ConnectivityEvent>.empty();

    return (_controller ??= StreamController<ConnectivityEvent>.broadcast()).stream;
  }

  /// Queues [event] for the next microtask. Dropped outright when nobody is listening yet or the
  /// controller has closed, which is fine: late subscribers never see past events anyway.
  void emit(ConnectivityEvent event) {
    final controller = _controller;
    if (controller == null || !controller.hasListener) return;

    scheduleMicrotask(() {
      if (controller.isClosed) return;

      controller.add(event);
    });
  }

  /// Emits [DisposedEvent], waits for it to flush, then closes. Does nothing if no controller was
  /// ever built.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final controller = _controller;
    if (controller == null) return;

    emit(const DisposedEvent());
    await Future<void>.value();

    await controller.close();
    _controller = null;
  }
}
