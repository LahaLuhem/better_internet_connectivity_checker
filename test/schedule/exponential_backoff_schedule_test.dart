import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';

import '../support/bdd.dart';

// Bounds and midpoint of a real draw. Top-level so the tear-offs stay constant expressions.
double lowest() => 0;

double midpoint() => 0.5;

double highest() => 1;

void main() {
  ScheduleContext contextWith(int consecutiveFailures, {Duration? baseInterval}) => ScheduleContext(
    baseInterval: baseInterval ?? const Duration(seconds: 10),
    consecutiveFailures: consecutiveFailures,
    lastStatus: const Unreachable(failedProbes: []),
  );

  feature('ExponentialBackoffSchedule ladder', () {
    scenarioOutline<({int consecutiveFailures, Duration expectedDelay})>(
      'doubles from the second failure, leaving the first at the base interval',
      examples: {
        'healthy': (consecutiveFailures: 0, expectedDelay: const Duration(seconds: 10)),
        'first failure': (consecutiveFailures: 1, expectedDelay: const Duration(seconds: 10)),
        'second failure': (consecutiveFailures: 2, expectedDelay: const Duration(seconds: 20)),
        'third failure': (consecutiveFailures: 3, expectedDelay: const Duration(seconds: 40)),
        'fourth failure': (consecutiveFailures: 4, expectedDelay: const Duration(seconds: 80)),
      },
      outline: (example) {
        const schedule = ExponentialBackoffSchedule(
          maxDelay: Duration(minutes: 30),
          randomizationFactor: 0,
        );

        final delay = schedule.nextDelay(contextWith(example.consecutiveFailures));

        check(delay).equals(example.expectedDelay);
      },
    );

    scenario('scales the whole ladder off the base interval', () {
      const schedule = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 30),
        randomizationFactor: 0,
      );

      final delay = schedule.nextDelay(contextWith(3, baseInterval: const Duration(seconds: 30)));

      check(delay).equals(const Duration(minutes: 2));
    });

    scenario('honours a custom multiplier', () {
      const schedule = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 30),
        multiplier: 3,
        randomizationFactor: 0,
      );

      check(schedule.nextDelay(contextWith(2))).equals(const Duration(seconds: 30));
      check(schedule.nextDelay(contextWith(3))).equals(const Duration(seconds: 90));
    });

    scenario('a multiplier of 1 degenerates to a fixed interval', () {
      const schedule = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 30),
        multiplier: 1,
        randomizationFactor: 0,
      );
      const fixedSchedule = FixedIntervalSchedule();

      for (final consecutiveFailures in [0, 1, 5, 50]) {
        final context = contextWith(consecutiveFailures);

        check(schedule.nextDelay(context)).equals(fixedSchedule.nextDelay(context));
      }
    });
  });

  feature('ExponentialBackoffSchedule bounds', () {
    scenario('caps at maxDelay', () {
      const schedule = ExponentialBackoffSchedule(
        maxDelay: Duration(seconds: 45),
        randomizationFactor: 0,
      );

      check(schedule.nextDelay(contextWith(3))).equals(const Duration(seconds: 40));
      check(schedule.nextDelay(contextWith(4))).equals(const Duration(seconds: 45));
      check(schedule.nextDelay(contextWith(9))).equals(const Duration(seconds: 45));
    });

    scenario('survives a streak long enough to overflow the growth factor', () {
      const schedule = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 5),
        randomizationFactor: 0,
      );

      // 2^2999 overflows a double to infinity; building the Duration first would throw.
      check(schedule.nextDelay(contextWith(3000))).equals(const Duration(minutes: 5));
    });

    scenario('survives an absurd multiplier', () {
      const schedule = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 5),
        multiplier: 1e300,
        randomizationFactor: 0,
      );

      check(schedule.nextDelay(contextWith(3))).equals(const Duration(minutes: 5));
    });

    scenario('never returns less than the base interval when jitter is off', () {
      // maxDelay below the base is a misconfiguration; pinning to the base beats returning a
      // shorter delay than asked for, or zero.
      const schedule = ExponentialBackoffSchedule(
        maxDelay: Duration(seconds: 1),
        randomizationFactor: 0,
      );

      check(schedule.nextDelay(contextWith(0))).equals(const Duration(seconds: 10));
      check(schedule.nextDelay(contextWith(5))).equals(const Duration(seconds: 10));
    });

    scenario('rejects a multiplier below 1 (dev-time check)', () {
      check(() => ExponentialBackoffSchedule(maxDelay: const Duration(minutes: 5), multiplier: 0.5))
          .throws<AssertionError>();
    });
  });

  feature('ExponentialBackoffSchedule jitter', () {
    scenario('spreads a grown delay symmetrically around its exact value', () {
      // Streak 3 is nominally 40s. At +/-25% that spans 30s..50s, midpoint back at 40s.
      const lowSchedule = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 30),
        jitterSource: lowest,
      );
      const midSchedule = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 30),
        jitterSource: midpoint,
      );
      const highSchedule = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 30),
        jitterSource: highest,
      );

      check(lowSchedule.nextDelay(contextWith(3))).equals(const Duration(seconds: 30));
      check(midSchedule.nextDelay(contextWith(3))).equals(const Duration(seconds: 40));
      check(highSchedule.nextDelay(contextWith(3))).equals(const Duration(seconds: 50));
    });

    scenario('spreads the base cadence too, without clamping it back up', () {
      // The moved floor is what keeps this symmetric: base 10s at -25% is 7.5s, the floor exactly.
      const lowSchedule = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 30),
        jitterSource: lowest,
      );
      const highSchedule = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 30),
        jitterSource: highest,
      );

      check(lowSchedule.nextDelay(contextWith(0))).equals(const Duration(milliseconds: 7500));
      check(highSchedule.nextDelay(contextWith(0))).equals(const Duration(milliseconds: 12500));
    });

    scenario('honours the moved floor at its lowest draw', () {
      const schedule = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 30),
        randomizationFactor: 0.5,
        jitterSource: lowest,
      );

      // factor 0.5 puts the floor at base/2, where the lowest draw lands.
      check(schedule.nextDelay(contextWith(0))).equals(const Duration(seconds: 5));
    });

    scenario('keeps maxDelay a hard ceiling on the highest draw', () {
      const schedule = ExponentialBackoffSchedule(
        maxDelay: Duration(seconds: 45),
        jitterSource: highest,
      );

      // Streak 4 is nominally capped at 45s; +25% would be 56.25s, which must not escape.
      check(schedule.nextDelay(contextWith(4))).equals(const Duration(seconds: 45));
    });

    scenario('a zero factor reproduces the exact ladder', () {
      const jittered = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 30),
        randomizationFactor: 0,
        jitterSource: highest,
      );

      check(jittered.nextDelay(contextWith(3))).equals(const Duration(seconds: 40));
    });

    scenario('every draw from the default source lands inside the spread', () {
      const schedule = ExponentialBackoffSchedule(maxDelay: Duration(minutes: 30));
      const nominal = Duration(seconds: 40);
      final lowerBound = nominal * 0.75;
      final upperBound = nominal * 1.25;

      for (var draw = 0; draw < 500; draw++) {
        final delay = schedule.nextDelay(contextWith(3));

        check(delay).isGreaterOrEqual(lowerBound);
        check(delay).isLessOrEqual(upperBound);
      }
    });

    scenario('the default source actually varies', () {
      const schedule = ExponentialBackoffSchedule(maxDelay: Duration(minutes: 30));

      final delays = {for (var draw = 0; draw < 50; draw++) schedule.nextDelay(contextWith(3))};

      check(delays).length.isGreaterThan(1);
    });

    scenario('rejects a factor of 1 or more (dev-time check)', () {
      check(
        () => ExponentialBackoffSchedule(
          maxDelay: const Duration(minutes: 5),
          randomizationFactor: 1,
        ),
      ).throws<AssertionError>();
    });
  });

  feature('ExponentialBackoffSchedule construction', () {
    scenario('is const-constructible so one instance can be shared', () {
      const first = ExponentialBackoffSchedule(maxDelay: Duration(minutes: 5));
      const second = ExponentialBackoffSchedule(maxDelay: Duration(minutes: 5));

      check(first).identicalTo(second);
    });

    scenario('exposes its configuration', () {
      const schedule = ExponentialBackoffSchedule(maxDelay: Duration(minutes: 5), multiplier: 4);

      check(schedule.maxDelay).equals(const Duration(minutes: 5));
      check(schedule.multiplier).equals(4);
      check(schedule.randomizationFactor).equals(0.25);
    });
  });
}
