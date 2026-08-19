import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';

import '../../support/bdd.dart';

void main() {
  feature('ScheduleContext', () {
    scenario('exposes every field it was built with', () {
      const context = ScheduleContext(
        baseInterval: Duration(seconds: 10),
        consecutiveFailures: 3,
        lastStatus: Unreachable(failedProbes: []),
      );

      check(context.baseInterval).equals(const Duration(seconds: 10));
      check(context.consecutiveFailures).equals(3);
      check(context.lastStatus).isA<Unreachable>();
    });

    scenario('is const-constructible so schedules can share one', () {
      const first = ScheduleContext(
        baseInterval: Duration(seconds: 10),
        consecutiveFailures: 0,
        lastStatus: Reachable(responseTime: Duration(milliseconds: 50), quality: .good),
      );
      const second = ScheduleContext(
        baseInterval: Duration(seconds: 10),
        consecutiveFailures: 0,
        lastStatus: Reachable(responseTime: Duration(milliseconds: 50), quality: .good),
      );

      check(first).identicalTo(second);
    });

    scenario('rejects a negative failure streak (dev-time check)', () {
      check(
        () => ScheduleContext(
          baseInterval: const Duration(seconds: 10),
          consecutiveFailures: -1,
          lastStatus: const Unreachable(failedProbes: []),
        ),
      ).throws<AssertionError>();
    });
  });

  feature('ScheduleContext.toString', () {
    scenario('renders every field in stable diagnostic form', () {
      const context = ScheduleContext(
        baseInterval: Duration(seconds: 10),
        consecutiveFailures: 2,
        lastStatus: Unreachable(failedProbes: []),
      );

      check(context.toString()).equals(
        'ScheduleContext('
        'baseInterval: 0:00:10.000000, '
        'consecutiveFailures: 2, '
        'lastStatus: Unreachable(failedProbes: []))',
      );
    });
  });
}
