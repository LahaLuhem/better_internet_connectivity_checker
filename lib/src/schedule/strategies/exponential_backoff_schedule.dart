/// @docImport 'fixed_interval_schedule.dart';
library;

import 'dart:math';

import '../../data/typedefs.dart';
import '../check_schedule.dart';
import '../models/schedule_context.dart';

final _random = Random();

double _defaultJitterSource() => _random.nextDouble();

/// A [CheckSchedule] that widens the gap while checks keep failing, and snaps back on recovery.
///
/// `baseInterval * multiplier^(consecutiveFailures - 1)`, spread by [randomizationFactor] and held
/// between a jittered floor and [maxDelay]. The first failure retries at the base, so a 10-second
/// `checkInterval` at the defaults gives nominally 10s, 10s, 20s, 40s, 80s, each ±25 %.
///
/// Backed off, a connection that returns is not noticed until the next check. Pair with
/// `externalRecheckTrigger` and keep [maxDelay] inside the staleness the app tolerates.
final class const ExponentialBackoffSchedule({
  required final Duration _maxDelay,
  final double _multiplier = 2,
  final double _randomizationFactor = 0.25,
  final JitterSource _jitterSource = _defaultJitterSource,
}) implements CheckSchedule {
  /// Creates an [ExponentialBackoffSchedule].
  ///
  /// [maxDelay] is unasserted: `Duration` comparison is not a constant expression, so asserting it
  /// would cost the `const` constructor. At or below the base interval it pins every delay there.
  this
    : assert(_multiplier >= 1, 'multiplier must be at least 1'),
      assert(
        _randomizationFactor >= 0 && _randomizationFactor < 1,
        'randomizationFactor must be at least 0 and below 1',
      );

  /// The ceiling on the returned delay. Jitter never pushes past it.
  Duration get maxDelay => _maxDelay;

  /// How much the delay grows per consecutive failure after the first.
  ///
  /// A multiplier of `1` never grows, which matches [FixedIntervalSchedule].
  double get multiplier => _multiplier;

  /// How far each delay is spread either side of its computed value, as a fraction.
  ///
  /// Defaults to `0.25`, so a fleet that dropped together does not return in lockstep. `0` makes
  /// every delay exact.
  double get randomizationFactor => _randomizationFactor;

  @override
  Duration nextDelay(ScheduleContext scheduleContext) {
    final baseInterval = scheduleContext.baseInterval;
    final growthExponent = max(0, scheduleContext.consecutiveFailures - 1);
    final growthFactor = pow(_multiplier, growthExponent).toDouble();
    // Capped as a ratio, not by building the Duration first: an unbounded exponent makes
    // `Duration * factor` saturate at int64, or throw outright on an infinite factor.
    final ceilingFactor = _maxDelay.inMicroseconds / baseInterval.inMicroseconds;
    final grownDelay = growthFactor >= ceilingFactor ? _maxDelay : baseInterval * growthFactor;
    final spreadDelay = _jittered(grownDelay);
    // Floor moves with the jitter: clamping a spread base cadence back up would pin half the draws
    // to one value. The factor-below-1 assert is what keeps this off zero.
    final floorDelay = baseInterval * (1 - _randomizationFactor);

    if (spreadDelay > _maxDelay) return _maxDelay;

    return spreadDelay > floorDelay ? spreadDelay : floorDelay;
  }

  Duration _jittered(Duration delay) {
    if (_randomizationFactor == 0) return delay;

    return delay * (_randomizationFactor * (_jitterSource() * 2 - 1) + 1);
  }
}
