/// @docImport 'fixed_interval_schedule.dart';
library;

import 'dart:math';

import '../check_schedule.dart';
import '../models/schedule_context.dart';

/// A [CheckSchedule] that widens the gap while checks keep failing, and snaps back on recovery.
///
/// The delay is `baseInterval * multiplier^(consecutiveFailures - 1)`, held between the base interval
/// and [maxDelay]. The first failure retries at the base interval and growth starts from the second,
/// so a 10-second `checkInterval` at the default multiplier gives 10s, 10s, 20s, 40s, 80s, up to the cap.
///
/// This trades recovery latency for radio and battery cost: while backed off, a connection that comes
/// back is not noticed until the next check. Pair it with `InternetConnection`'s
/// `externalRecheckTrigger` so an OS network-change signal cuts the wait short, and keep [maxDelay]
/// inside the staleness the app can live with.
final class const ExponentialBackoffSchedule({
  required final Duration _maxDelay,
  final double _multiplier = 2,
}) implements CheckSchedule {
  /// Creates an [ExponentialBackoffSchedule].
  ///
  /// [maxDelay] carries no assert because `Duration` comparison is not available in a constant
  /// expression, which would cost every caller the `const` constructor. A [maxDelay] at or below the
  /// base interval instead pins every delay to the base.
  this : assert(_multiplier >= 1, 'multiplier must be at least 1');

  /// The ceiling on the returned delay.
  Duration get maxDelay => _maxDelay;

  /// How much the delay grows per consecutive failure after the first.
  ///
  /// A multiplier of `1` never grows, which matches [FixedIntervalSchedule].
  double get multiplier => _multiplier;

  @override
  Duration nextDelay(ScheduleContext scheduleContext) {
    final baseInterval = scheduleContext.baseInterval;
    final growthExponent = max(0, scheduleContext.consecutiveFailures - 1);
    final growthFactor = pow(_multiplier, growthExponent).toDouble();
    // Capped as a ratio instead of by building the grown Duration first: a long outage drives the
    // exponent unbounded, where `Duration * factor` silently saturates at int64 and an infinite
    // factor throws outright.
    final ceilingFactor = _maxDelay.inMicroseconds / baseInterval.inMicroseconds;
    final grownDelay = growthFactor >= ceilingFactor ? _maxDelay : baseInterval * growthFactor;

    return grownDelay > baseInterval ? grownDelay : baseInterval;
  }
}
