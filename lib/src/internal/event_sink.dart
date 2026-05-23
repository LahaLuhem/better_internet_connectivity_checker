part of '../internet_connection.dart';

/// Internal sink that fans [ConnectivityEvent]s out to a broadcast stream.
///
/// Every emission is queued via [scheduleMicrotask], so a slow subscriber
/// cannot stall the caller's frame. [dispose] emits the terminal
/// [DisposedEvent] and yields once to let the queued add flush before the
/// underlying controller is closed — subscribers attached at dispose time
/// still observe the dispose signal.
final class _EventSink {
  final _controller = StreamController<ConnectivityEvent>.broadcast();

  Stream<ConnectivityEvent> get stream => _controller.stream;

  /// Queues [event] for microtask-deferred dispatch.
  ///
  /// Fast-paths the no-subscriber case — when nothing is attached to the
  /// broadcast stream, the event would land in an empty broadcast and the
  /// microtask hop is pure overhead, so we skip queuing it entirely. A
  /// subscriber attaching in the window between [emit] returning and the
  /// would-be microtask firing therefore misses the event; this matches
  /// the broadcast-stream contract that late subscribers never see past
  /// events.
  ///
  /// Also silently drops the event if the controller has already been
  /// closed — emissions raced against [dispose] are best-effort by design.
  void emit(ConnectivityEvent event) {
    if (!_controller.hasListener) return;

    scheduleMicrotask(() {
      if (_controller.isClosed) return;

      _controller.add(event);
    });
  }

  /// Emits [DisposedEvent] and closes the underlying controller after the
  /// queued emission has flushed.
  Future<void> dispose() async {
    emit(const DisposedEvent());
    await Future<void>.value();

    await _controller.close();
  }
}
