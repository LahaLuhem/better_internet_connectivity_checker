import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import 'support/bdd.dart';
import 'support/recording_observer.dart';

void main() {
  const reachable = Reachable(responseTime: Duration(milliseconds: 50), quality: .good);
  const unreachable = Unreachable(failedProbes: []);
  const shortInterval = Duration(seconds: 3);
  const longInterval = Duration(seconds: 5);
  const scheduleContext = ScheduleContext(
    baseInterval: longInterval,
    consecutiveFailures: 2,
    lastStatus: unreachable,
  );
  const triggerError = FormatException('bad signal');

  feature('attachObserver', () {
    // When each event fires belongs to InternetConnection, and lives in
    // internet_connection_events_test.dart. All that is left here is the routing on top.
    scenario('hands every event to its matching callback, payload intact', () async {
      final events = StreamController<ConnectivityEvent>();
      final observer = RecordingObserver();
      final subscription = attachObserver(events.stream, observer);
      addTearDown(subscription.cancel);

      <ConnectivityEvent>[
        const StatusEmittedEvent(previous: unreachable, next: reachable),
        const CheckCompletedEvent(reachable),
        const NextCheckScheduledEvent(delay: shortInterval, scheduleContext: scheduleContext),
        const ExternalTriggerFiredEvent(),
        const ExternalTriggerErrorEvent(triggerError, StackTrace.empty),
        const CheckIntervalChangedEvent(previous: longInterval, next: shortInterval),
        const SlowThresholdChangedEvent(previous: null, next: shortInterval),
        const DisposedEvent(),
      ].forEach(events.add);
      await events.close();

      check(observer.events.map((recorded) => recorded.runtimeType).toList()).deepEquals([
        StatusChangeEmitted,
        CheckCompleted,
        NextCheckScheduled,
        ExternalTriggerFired,
        ExternalTriggerError,
        CheckIntervalChanged,
        SlowThresholdChanged,
        DisposeEvent,
      ]);

      // Same-typed pairs are what a mis-wired callback silently swaps.
      check(observer.events.whereType<StatusChangeEmitted>().single)
        ..has('previous', (recorded) => recorded.previous).equals(unreachable)
        ..has('next', (recorded) => recorded.next).equals(reachable);
      check(observer.events.whereType<CheckIntervalChanged>().single)
        ..has('previous', (recorded) => recorded.previous).equals(longInterval)
        ..has('next', (recorded) => recorded.next).equals(shortInterval);
      check(observer.events.whereType<SlowThresholdChanged>().single)
        ..has('previous', (recorded) => recorded.previous).isNull
        ..has('next', (recorded) => recorded.next).equals(shortInterval);
      check(observer.events.whereType<ExternalTriggerError>().single)
          .has('error', (recorded) => recorded.error)
          .equals(triggerError);
      check(observer.events.whereType<NextCheckScheduled>().single)
        ..has('delay', (recorded) => recorded.delay).equals(shortInterval)
        ..has('scheduleContext', (recorded) => recorded.scheduleContext).equals(scheduleContext);
      check(observer.events.whereType<CheckCompleted>().single)
          .has('result', (recorded) => recorded.result)
          .equals(reachable);
    });
  });
}
