import '../../schedule/models/schedule_context.dart';
import '../../status/internet_status.dart';

part 'instances/check_completed_event.dart';
part 'instances/check_interval_changed_event.dart';
part 'instances/disposed_event.dart';
part 'instances/external_trigger_error_event.dart';
part 'instances/external_trigger_fired_event.dart';
part 'instances/next_check_scheduled_event.dart';
part 'instances/slow_threshold_changed_event.dart';
part 'instances/status_emitted_event.dart';

/// One thing that happened inside an `InternetConnection`. Sealed, so a `switch` over them is
/// exhaustive and the compiler nags you when a new one lands.
sealed class ConnectivityEvent {
  /// Creates a [ConnectivityEvent].
  const new();
}
