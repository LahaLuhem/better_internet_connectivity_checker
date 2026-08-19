import 'models/schedule_context.dart';
import 'strategies/fixed_interval_schedule.dart';

/// Decides how long to wait before the next periodic check.
///
/// The third pluggable layer, alongside `ConnectivityProbe` (how one check runs) and
/// `ReachabilityPolicy` (how results roll up). Built-ins: [FixedIntervalSchedule] (the default,
/// same gap every time) and `ExponentialBackoffSchedule` (widening gaps while checks keep failing).
///
/// Stateless by convention, and built-ins are `const`-constructible so they can be shared. The
/// streak arrives on [ScheduleContext], so the common cases need no state. Kept an interface rather
/// than a typedef so a schedule that *does* need state can hold fields, e.g. one counting
/// `Reachable(slow)` as a failure, which [ScheduleContext.consecutiveFailures] deliberately does not.
abstract interface class CheckSchedule {
  /// Returns the delay before the next check, given the state after the one that just finished.
  ///
  /// Called once per scheduled check. Must return a non-negative [Duration]; a zero delay busy-loops
  /// the scheduler.
  Duration nextDelay(ScheduleContext scheduleContext);
}
