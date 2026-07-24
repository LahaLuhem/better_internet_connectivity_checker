import 'dart:async';
import 'dart:io';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
// Internal collaborator (not exported): imported directly because its log
// seam is the only way to observe the warning without capturing
// `dart:developer` VM-service records.
import 'package:better_internet_connectivity_checker/src/observer/slow_callback_watchdog.dart';
import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import 'support/bdd.dart';

void main() {
  const reachable = Reachable(responseTime: Duration(milliseconds: 5), quality: .good);
  const checkCompleted = CheckCompletedEvent(reachable);
  const statusEmitted = StatusEmittedEvent(previous: null, next: reachable);

  SlowCallbackWatchdog watchdogWith(
    List<String> warnings, {
    Duration threshold = const Duration(milliseconds: 8),
  }) => SlowCallbackWatchdog(
    observerType: PrintingConnectivityObserver,
    threshold: threshold,
    logSink: warnings.add,
  );

  feature('SlowCallbackWatchdog', () {
    scenario('fast callback does not warn and still dispatches', () {
      final warnings = <String>[];

      var dispatched = false;
      watchdogWith(warnings).measure(checkCompleted, () => dispatched = true);

      check(dispatched).isTrue();
      check(warnings).isEmpty();
    });

    scenario('overrunning callback warns once with observer type and callback name', () {
      final warnings = <String>[];

      watchdogWith(warnings).measure(checkCompleted, () => sleep(const Duration(milliseconds: 20)));

      check(warnings).length.equals(1);
      check(warnings.single)
        ..contains('PrintingConnectivityObserver.onCheckCompleted')
        ..contains('budget: 8 ms')
        ..contains('Isolate.run');
    });

    scenario('same event type never warns twice', () {
      final warnings = <String>[];

      watchdogWith(warnings)
        ..measure(checkCompleted, () => sleep(const Duration(milliseconds: 20)))
        ..measure(checkCompleted, () => sleep(const Duration(milliseconds: 20)));

      check(warnings).length.equals(1);
    });

    scenario('distinct event types warn independently', () {
      final warnings = <String>[];

      watchdogWith(warnings)
        ..measure(checkCompleted, () => sleep(const Duration(milliseconds: 20)))
        ..measure(statusEmitted, () => sleep(const Duration(milliseconds: 20)));

      check(warnings).length.equals(2);
      check(warnings.last).contains('onStatusChangeEmitted');
    });

    scenario("a fast pass does not consume the event type's single warning", () {
      final warnings = <String>[];

      // Under budget first: must not mark the event type as already-warned.
      watchdogWith(warnings)
        // Intentionally instant.
        // ignore: no-empty-block
        ..measure(checkCompleted, () {})
        ..measure(checkCompleted, () => sleep(const Duration(milliseconds: 20)));

      check(warnings).length.equals(1);
    });
  });

  feature('attachObserver watchdog', () {
    scenario('slow observer still receives every event through the timed path', () async {
      // The warning itself goes to dart:developer (not capturable here). This pins the load-bearing part -
      // the watchdog wrapper must not swallow, reorder, or double-dispatch events.
      final controller = StreamController<ConnectivityEvent>.broadcast();
      addTearDown(controller.close);

      final observer = _BlockingCountingObserver();
      attachObserver(
        controller.stream,
        observer,
        slowCallbackThreshold: const Duration(milliseconds: 1),
      );

      controller
        ..add(checkCompleted)
        ..add(checkCompleted);
      await Future<void>.delayed(.zero);

      check(observer.checkCompletedCalls).equals(2);
    });
  });
}

// Test-specific implementation
// ignore: prefer-match-file-name
final class _BlockingCountingObserver extends ConnectivityObserver {
  var checkCompletedCalls = 0;

  @override
  void onCheckCompleted(InternetStatus result) {
    checkCompletedCalls++;
    sleep(const Duration(milliseconds: 5));
  }
}
