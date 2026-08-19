part of '../internet_connection.dart';

/// Internal wiring for the optional external recheck trigger.
///
/// Owns the underlying `StreamSubscription` and the trigger stream reference. The coordinator drives
/// the lifecycle via [start] and [stop]. When the constructor's `trigger` argument is null, [start]
/// and [stop] are inert — the link silently does nothing rather than failing, mirroring the package's
/// contract that an external trigger is optional.
///
/// [start] is idempotent: calling it while already subscribed does not re-subscribe. [stop] cancels
/// and clears the subscription. A subsequent [start] re-subscribes from scratch.
final class _ExternalTriggerLink {
  final Stream<void>? _trigger;
  final void Function() _onTrigger;
  final void Function(Object error, StackTrace stackTrace) _onError;
  StreamSubscription<void>? _subscription;

  new({required this._trigger, required this._onTrigger, required this._onError});

  /// Subscribes to the trigger stream if not already subscribed.
  void start() {
    _subscription ??= _trigger?.listen((_) => _onTrigger(), onError: _onError);
  }

  /// Cancels the underlying subscription and clears it so a later [start] re-subscribes from scratch.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
