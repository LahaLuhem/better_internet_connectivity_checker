part of '../connectivity_event.dart';

/// A deduped status change went out on the public status stream.
final class const StatusEmittedEvent({
  /// The status before, or null on the first emission of a fresh subscription.
  required final InternetStatus? previous,

  /// The status after.
  required final InternetStatus next,
}) extends ConnectivityEvent {
  /// Creates a [StatusEmittedEvent].
  this;
  // coverage:ignore-start
  @override
  String toString() => 'StatusEmittedEvent(previous: $previous, next: $next)';
  // coverage:ignore-end
}
