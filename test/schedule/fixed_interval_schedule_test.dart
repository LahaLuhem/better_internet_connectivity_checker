import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';

import '../support/bdd.dart';

void main() {
  ScheduleContext contextWith({required int consecutiveFailures, InternetStatus? lastStatus}) =>
      ScheduleContext(
        baseInterval: const Duration(seconds: 10),
        consecutiveFailures: consecutiveFailures,
        lastStatus: lastStatus ?? const Unreachable(failedProbes: []),
      );

  feature('FixedIntervalSchedule', () {
    scenarioOutline<({int consecutiveFailures, Duration expectedDelay})>(
      'returns the base interval regardless of the failure streak',
      examples: {
        'healthy': (consecutiveFailures: 0, expectedDelay: const Duration(seconds: 10)),
        'first failure': (consecutiveFailures: 1, expectedDelay: const Duration(seconds: 10)),
        'long outage': (consecutiveFailures: 500, expectedDelay: const Duration(seconds: 10)),
      },
      outline: (example) {
        final delay = const FixedIntervalSchedule().nextDelay(
          contextWith(consecutiveFailures: example.consecutiveFailures),
        );

        check(delay).equals(example.expectedDelay);
      },
    );

    scenario('ignores connection quality', () {
      const schedule = FixedIntervalSchedule();

      final goodDelay = schedule.nextDelay(
        contextWith(
          consecutiveFailures: 0,
          lastStatus: const Reachable(responseTime: Duration(milliseconds: 20), quality: .good),
        ),
      );
      final slowDelay = schedule.nextDelay(
        contextWith(
          consecutiveFailures: 0,
          lastStatus: const Reachable(responseTime: Duration(seconds: 2), quality: .slow),
        ),
      );

      check(goodDelay).equals(slowDelay);
    });

    scenario('tracks a base interval reassigned at runtime', () {
      const schedule = FixedIntervalSchedule();

      final delay = schedule.nextDelay(
        const ScheduleContext(
          baseInterval: Duration(minutes: 5),
          consecutiveFailures: 4,
          lastStatus: Unreachable(failedProbes: []),
        ),
      );

      check(delay).equals(const Duration(minutes: 5));
    });
  });
}
