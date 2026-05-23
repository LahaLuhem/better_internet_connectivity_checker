import '../../status/internet_status.dart';

part 'instances/check_completed_event.dart';
part 'instances/check_interval_changed_event.dart';
part 'instances/disposed_event.dart';
part 'instances/external_trigger_error_event.dart';
part 'instances/external_trigger_fired_event.dart';
part 'instances/slow_threshold_changed_event.dart';
part 'instances/status_emitted_event.dart';

/// Lifecycle event surfaced by the diagnostic stream of an
/// `InternetConnection`.
///
/// Sealed so subscribers can pattern-match exhaustively:
///
/// ```dart
/// switch (event) {
///   case StatusEmittedEvent(:final previous, :final next):
///     log('status: $previous -> $next');
///   case CheckCompletedEvent(:final result):
///     log('check: $result');
///   // ... and so on
/// }
/// ```
sealed class ConnectivityEvent {
  /// Subclasses are sealed; external code may not extend this type.
  const ConnectivityEvent();
}
