part of '../internet_connection.dart';

/// Owns the subscription behind the optional external recheck trigger. With a null `trigger`, [start]
/// and [stop] quietly do nothing, because the trigger is meant to be optional.
final class _ExternalTriggerLink({
  required final Stream<void>? _trigger,
  required final void Function() _onTrigger,
  required final void Function(Object error, StackTrace stackTrace) _onError,
}) {
  StreamSubscription<void>? _subscription;

  /// Subscribes to the trigger stream if not already subscribed.
  void start() {
    _subscription ??= _trigger?.listen((_) => _onTrigger(), onError: _onError);
  }

  /// Cancels and clears the subscription, so a later [start] subscribes afresh.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
