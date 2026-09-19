/// @docImport 'strategies/exponential_backoff_schedule.dart';
/// @docImport 'strategies/fixed_interval_schedule.dart';
library;

import 'models/schedule_context.dart';

/// Decides how long to wait before the next check. [FixedIntervalSchedule] keeps the same gap,
/// [ExponentialBackoffSchedule] widens it while checks keep failing. Why cadence is its own seam and
/// not `package:retry`: [Appendix](https://github.com/LahaLuhem/better_internet_connectivity_checker/blob/main/APPENDIX.md#why-cadence-is-its-own-seam).
///
/// The failure streak comes in on [ScheduleContext], so the usual cases need no state of their own.
/// It's an interface rather than a typedef for the ones that do, like a schedule that counts a
/// slow-but-reachable result as a failure, which [ScheduleContext.consecutiveFailures] doesn't.
abstract interface class CheckSchedule {
  /// The gap before the next check, asked once per scheduled check. Keep it above zero, or the
  /// scheduler busy-loops.
  Duration nextDelay(ScheduleContext scheduleContext);
}
