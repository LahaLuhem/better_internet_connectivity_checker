part of '../connectivity_event.dart';

/// Emitted when a deduplicated status transition is published to the public status stream.
final class const StatusEmittedEvent({
  /// The previously emitted status, or null on the first emission of a fresh subscription.
  required final InternetStatus? previous,

  /// The newly emitted status.
  required final InternetStatus next,
}) extends ConnectivityEvent {
  /// Creates an emitted-status event capturing the deduplicated transition.
  this;

  // Debug-only toString delegation; excluded from coverage.
  // coverage:ignore-start
  @override
  String toString() => 'StatusEmittedEvent(previous: $previous, next: $next)';
  // coverage:ignore-end
}
