/// @docImport 'exponential_backoff_schedule.dart';
library;

import '../check_schedule.dart';
import '../models/schedule_context.dart';

/// The default: the same gap after every check, pass or fail. Predictable, and the one you want
/// when spotting recovery quickly matters more than the radio cost of retrying.
///
/// Swap in [ExponentialBackoffSchedule] to back off while checks keep failing.
final class FixedIntervalSchedule implements CheckSchedule {
  /// Creates a [FixedIntervalSchedule].
  const new();

  @override
  Duration nextDelay(ScheduleContext scheduleContext) => scheduleContext.baseInterval;
}
