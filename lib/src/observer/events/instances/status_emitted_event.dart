part of '../connectivity_event.dart';

/// Emitted when a deduplicated status transition is published to
/// the public status stream.
final class StatusEmittedEvent extends ConnectivityEvent {
  /// The previously emitted status, or null on the very first emission
  /// for a fresh subscription.
  final InternetStatus? previous;

  /// The newly emitted status.
  final InternetStatus next;

  /// Creates an emitted-status event capturing the deduplicated transition.
  const StatusEmittedEvent({required this.previous, required this.next});

  // Debug-only toString delegation; excluded from coverage.
  // coverage:ignore-start
  @override
  String toString() => 'StatusEmittedEvent(previous: $previous, next: $next)';
  // coverage:ignore-end
}
