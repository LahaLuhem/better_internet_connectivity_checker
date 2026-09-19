/// @docImport 'fixed_interval_schedule.dart';
library;

import 'dart:math';

import '../../data/typedefs.dart';
import '../check_schedule.dart';
import '../models/schedule_context.dart';

final _random = Random();

double _defaultJitterSource() => _random.nextDouble();

/// Widens the gap while checks keep failing, and snaps back the moment one succeeds.
///
/// `baseInterval * multiplier^(consecutiveFailures - 1)`, spread by [randomizationFactor] and kept
/// between a jittered floor and [maxDelay]. At the defaults a 10-second interval gives roughly 10s,
/// 10s, 20s, 40s, 80s, each give or take 25%.
///
/// The catch: once backed off, a connection that comes back isn't noticed until the next check. Pair
/// it with `externalRecheckTrigger` and keep [maxDelay] inside what your app can stomach.
final class const ExponentialBackoffSchedule({
  required final Duration _maxDelay,
  final double _multiplier = 2,
  final double _randomizationFactor = 0.25,
  final JitterSource _jitterSource = _defaultJitterSource,
}) implements CheckSchedule {
  /// Creates an [ExponentialBackoffSchedule]. [maxDelay] goes unasserted because comparing
  /// `Duration`s isn't a const expression, and the assert would cost the const constructor.
  this
    : assert(_multiplier >= 1, 'multiplier must be at least 1'),
      assert(
        _randomizationFactor >= 0 && _randomizationFactor < 1,
        'randomizationFactor must be at least 0 and below 1',
      );

  /// The ceiling on the returned delay. Jitter never pushes past it.
  Duration get maxDelay => _maxDelay;

  /// How much the delay grows per failure after the first. `1` never grows, same as
  /// [FixedIntervalSchedule].
  double get multiplier => _multiplier;

  /// How far each delay is spread either side of its computed value. The default 0.25 stops a fleet
  /// that dropped together from all coming back at once. `0` makes every delay exact.
  double get randomizationFactor => _randomizationFactor;

  @override
  Duration nextDelay(ScheduleContext scheduleContext) {
    final baseInterval = scheduleContext.baseInterval;
    final growthExponent = max(0, scheduleContext.consecutiveFailures - 1);
    final growthFactor = pow(_multiplier, growthExponent).toDouble();
    // Capped as a ratio rather than by building the Duration first: a big enough exponent saturates
    // `Duration * factor` at int64, or throws outright once the factor goes infinite.
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
