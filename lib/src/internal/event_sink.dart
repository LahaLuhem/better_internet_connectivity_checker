part of '../internet_connection.dart';

/// Internal sink that fans [ConnectivityEvent]s out to a broadcast stream.
///
/// Every emission is queued via [scheduleMicrotask], so a slow subscriber
/// cannot stall the caller's frame. [dispose] emits the terminal
/// [DisposedEvent] and yields once to let the queued add flush before the
/// underlying controller is closed — subscribers attached at dispose time
/// still observe the dispose signal.
///
/// The underlying broadcast controller is **allocated lazily** — only on
/// first access to [stream]. Checkers whose consumers never subscribe to
/// the diagnostic stream (the common case for users who only watch
/// `onStatusChange`) pay no per-instance controller cost. The early-out
/// inside [emit] additionally short-circuits dispatch when the controller
/// exists but has no listeners.
final class _EventSink {
  // The analyser can't trace the lazy assignment in [stream] through `??=`
  // to the matching `controller.close()` in [dispose], so it flags this
  // field. The lifecycle is correct: `_controller` is null until first
  // [stream] access, then closed and nulled out by [dispose].
  // ignore: close_sinks
  StreamController<ConnectivityEvent>? _controller;
  var _disposed = false;

  /// The diagnostic event stream. Calling this getter for the first time
  /// allocates the backing broadcast controller; never calling it leaves
  /// the controller un-allocated for the lifetime of this sink.
  ///
  /// After [dispose] returns, this getter yields an empty broadcast that
  /// fires `done` immediately — matching the behaviour of the closed
  /// controller in the original eager-allocation design but without
  /// re-allocating on use-after-dispose.
  Stream<ConnectivityEvent> get stream {
    if (_disposed) return const Stream<ConnectivityEvent>.empty();

    return (_controller ??= StreamController<ConnectivityEvent>.broadcast()).stream;
  }

  /// Queues [event] for microtask-deferred dispatch.
  ///
  /// Fast-paths the no-subscriber case at two levels: (a) when the backing
  /// controller has not yet been allocated — nobody has ever subscribed to
  /// [stream] — the event is dropped without scheduling a microtask;
  /// (b) when the controller exists but has zero listeners, ditto. A
  /// subscriber attaching in the window between [emit] returning and the
  /// would-be microtask firing therefore misses the event; this matches
  /// the broadcast-stream contract that late subscribers never see past
  /// events.
  ///
  /// Also silently drops the event if the controller has already been
  /// closed — emissions raced against [dispose] are best-effort by design.
  void emit(ConnectivityEvent event) {
    final controller = _controller;
    if (controller == null || !controller.hasListener) return;

    scheduleMicrotask(() {
      if (controller.isClosed) return;

      controller.add(event);
    });
  }

  /// Emits [DisposedEvent] and closes the underlying controller after the
  /// queued emission has flushed. A no-op when no controller was ever
  /// allocated — the lazy-allocation early-out subsumes the dispose path.
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
