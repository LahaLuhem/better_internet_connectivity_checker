import '../check_schedule.dart';
import '../models/schedule_context.dart';

/// The default [CheckSchedule]: the same gap after every check, pass or fail.
///
/// Returns `InternetConnection.checkInterval` untouched, so an outage is retried at the same cadence
/// as a healthy connection. Predictable, and the right choice when a fast recovery signal matters
/// more than the radio cost of retrying.
///
/// Swap in `ExponentialBackoffSchedule` to widen the gap while checks keep failing.
final class FixedIntervalSchedule implements CheckSchedule {
  /// Creates a [FixedIntervalSchedule].
  const new();

  @override
  Duration nextDelay(ScheduleContext scheduleContext) => scheduleContext.baseInterval;
}
