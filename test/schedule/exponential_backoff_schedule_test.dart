import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';

import '../support/bdd.dart';

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
        const schedule = ExponentialBackoffSchedule(maxDelay: Duration(minutes: 30));

        final delay = schedule.nextDelay(contextWith(example.consecutiveFailures));

        check(delay).equals(example.expectedDelay);
      },
    );

    scenario('scales the whole ladder off the base interval', () {
      const schedule = ExponentialBackoffSchedule(maxDelay: Duration(minutes: 30));

      final delay = schedule.nextDelay(contextWith(3, baseInterval: const Duration(seconds: 30)));

      check(delay).equals(const Duration(minutes: 2));
    });

    scenario('honours a custom multiplier', () {
      const schedule = ExponentialBackoffSchedule(maxDelay: Duration(minutes: 30), multiplier: 3);

      check(schedule.nextDelay(contextWith(2))).equals(const Duration(seconds: 30));
      check(schedule.nextDelay(contextWith(3))).equals(const Duration(seconds: 90));
    });

    scenario('a multiplier of 1 degenerates to a fixed interval', () {
      const schedule = ExponentialBackoffSchedule(maxDelay: Duration(minutes: 30), multiplier: 1);
      const fixedSchedule = FixedIntervalSchedule();

      for (final consecutiveFailures in [0, 1, 5, 50]) {
        final context = contextWith(consecutiveFailures);

        check(schedule.nextDelay(context)).equals(fixedSchedule.nextDelay(context));
      }
    });
  });

  feature('ExponentialBackoffSchedule bounds', () {
    scenario('caps at maxDelay', () {
      const schedule = ExponentialBackoffSchedule(maxDelay: Duration(seconds: 45));

      check(schedule.nextDelay(contextWith(3))).equals(const Duration(seconds: 40));
      check(schedule.nextDelay(contextWith(4))).equals(const Duration(seconds: 45));
      check(schedule.nextDelay(contextWith(9))).equals(const Duration(seconds: 45));
    });

    scenario('survives a streak long enough to overflow the growth factor', () {
      const schedule = ExponentialBackoffSchedule(maxDelay: Duration(minutes: 5));

      // 2^2999 overflows a double to infinity; building the Duration first would throw.
      check(schedule.nextDelay(contextWith(3000))).equals(const Duration(minutes: 5));
    });

    scenario('survives an absurd multiplier', () {
      const schedule = ExponentialBackoffSchedule(
        maxDelay: Duration(minutes: 5),
        multiplier: 1e300,
      );

      check(schedule.nextDelay(contextWith(3))).equals(const Duration(minutes: 5));
    });

    scenario('never returns less than the base interval', () {
      // maxDelay below the base is a misconfiguration; pinning to the base beats returning a
      // shorter delay than asked for, or zero.
      const schedule = ExponentialBackoffSchedule(maxDelay: Duration(seconds: 1));

      check(schedule.nextDelay(contextWith(0))).equals(const Duration(seconds: 10));
      check(schedule.nextDelay(contextWith(5))).equals(const Duration(seconds: 10));
    });

    scenario('rejects a multiplier below 1 (dev-time check)', () {
      check(() => ExponentialBackoffSchedule(maxDelay: const Duration(minutes: 5), multiplier: 0.5))
          .throws<AssertionError>();
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
    });
  });
}
