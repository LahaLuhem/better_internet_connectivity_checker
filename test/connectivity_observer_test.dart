import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/scaffolding.dart';

import '_helpers/recording_observer.dart';
import '_helpers/stub_probe.dart';

void main() {
  final target = ProbeTarget(uri: Uri.https('example.com'));

  ProbeResult successResult(ProbeTarget t) =>
      ProbeResult.success(target: t, responseTime: const Duration(milliseconds: 50));

  ProbeResult failureResult(ProbeTarget t) =>
      ProbeResult.failure(target: t, responseTime: const Duration(milliseconds: 50));

  group('ConnectivityObserver default', () {
    test('omitted observer is silent and does not throw on any lifecycle event', () {
      // Exercises the private default no-op observer indirectly by running
      // a full check / emit / interval-change / dispose sequence without
      // passing one.
      final probe = StubProbe((t) async => successResult(t));
      final trigger = StreamController<void>.broadcast();
      addTearDown(trigger.close);

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          externalRecheckTrigger: trigger.stream,
          checkInterval: const Duration(seconds: 5),
        );
        final sub = connection.onStatusChange.listen(noopWithVal);
        async.flushMicrotasks();

        connection.setCheckInterval(const Duration(seconds: 3));
        trigger.add(null);
        async.elapse(const Duration(seconds: 3));

        unawaited(sub.cancel());
        unawaited(connection.dispose());
      });
    });
  });

  group('ConnectivityObserver wiring', () {
    test('onCheckCompleted fires after every scheduled check', () {
      final probe = StubProbe((t) async => successResult(t));

      fakeAsync((async) {
        final observer = RecordingObserver();
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          checkInterval: const Duration(seconds: 5),
          observer: observer,
        );
        connection.onStatusChange.listen(noopWithVal);

        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 10));

        // 1 first-listener check + 2 timer ticks.
        final checks = observer.events.whereType<CheckCompleted>().toList();
        check(checks).length.equals(3);
        check(checks.first.result).isA<Reachable>();

        unawaited(connection.dispose());
      });
    });

    test('checkOnce does not fire onCheckCompleted', () async {
      final probe = StubProbe((t) async => successResult(t));
      final observer = RecordingObserver();
      final connection = InternetConnection(targets: [target], probe: probe, observer: observer);
      addTearDown(connection.dispose);

      await connection.checkOnce();

      check(observer.events.whereType<CheckCompleted>()).isEmpty();
    });

    test('onStatusChangeEmitted fires only on kind transitions', () {
      var reachable = false;
      final probe = StubProbe((t) async => reachable ? successResult(t) : failureResult(t));

      fakeAsync((async) {
        final observer = RecordingObserver();
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          checkInterval: const Duration(seconds: 5),
          observer: observer,
        );
        connection.onStatusChange.listen(noopWithVal);

        async
          ..flushMicrotasks()
          // No transition between consecutive Unreachables.
          ..elapse(const Duration(seconds: 5));

        reachable = true;
        async.elapse(const Duration(seconds: 5));

        final emits = observer.events.whereType<StatusChangeEmitted>().toList();
        check(emits).length.equals(2);
        // First emit on a fresh stream: previous is null.
        check(emits.first.previous).isNull();
        check(emits.first.next).isA<Unreachable>();
        // Second emit: Unreachable -> Reachable.
        check(emits.last.previous).isA<Unreachable>();
        check(emits.last.next).isA<Reachable>();

        unawaited(connection.dispose());
      });
    });

    test('onExternalTriggerFired fires when the trigger emits', () {
      final probe = StubProbe((t) async => successResult(t));
      final trigger = StreamController<void>.broadcast();
      addTearDown(trigger.close);

      fakeAsync((async) {
        final observer = RecordingObserver();
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          externalRecheckTrigger: trigger.stream,
          checkInterval: const Duration(seconds: 60),
          observer: observer,
        );
        connection.onStatusChange.listen(noopWithVal);
        async.flushMicrotasks();

        trigger.add(null);
        async.flushMicrotasks();

        check(observer.events.whereType<ExternalTriggerFired>()).length.equals(1);

        unawaited(connection.dispose());
      });
    });

    test('onExternalTriggerError forwards trigger-stream errors', () {
      final probe = StubProbe((t) async => successResult(t));
      final trigger = StreamController<void>.broadcast();
      addTearDown(trigger.close);

      fakeAsync((async) {
        final observer = RecordingObserver();
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          externalRecheckTrigger: trigger.stream,
          checkInterval: const Duration(seconds: 60),
          observer: observer,
        );
        connection.onStatusChange.listen(noopWithVal);
        async.flushMicrotasks();

        trigger.addError(const FormatException('bad signal'), StackTrace.empty);
        async.flushMicrotasks();

        final errors = observer.events.whereType<ExternalTriggerError>().toList();
        check(errors).length.equals(1);
        check(errors.single.error).isA<FormatException>();

        unawaited(connection.dispose());
      });
    });

    test('onCheckIntervalChanged carries previous and next intervals', () {
      final probe = StubProbe((t) async => successResult(t));
      final observer = RecordingObserver();
      final connection = InternetConnection(
        targets: [target],
        probe: probe,
        checkInterval: const Duration(seconds: 5),
        observer: observer,
      );
      addTearDown(connection.dispose);

      connection.setCheckInterval(const Duration(seconds: 3));

      final changes = observer.events.whereType<CheckIntervalChanged>().toList();
      check(changes).length.equals(1);
      check(changes.single.previous).equals(const Duration(seconds: 5));
      check(changes.single.next).equals(const Duration(seconds: 3));
    });

    test('onSlowThresholdChanged carries previous and next thresholds', () {
      final probe = StubProbe((t) async => successResult(t));
      final observer = RecordingObserver();
      final connection = InternetConnection(
        targets: [target],
        probe: probe,
        slowThreshold: const Duration(milliseconds: 200),
        observer: observer,
      );
      addTearDown(connection.dispose);

      connection
        ..setSlowThreshold(const Duration(milliseconds: 50))
        ..setSlowThreshold(null);

      final changes = observer.events.whereType<SlowThresholdChanged>().toList();
      check(changes).length.equals(2);
      check(changes.first.previous).equals(const Duration(milliseconds: 200));
      check(changes.first.next).equals(const Duration(milliseconds: 50));
      check(changes.last.previous).equals(const Duration(milliseconds: 50));
      check(changes.last.next).isNull();
    });

    test('onDispose fires exactly once across multiple dispose calls', () async {
      final probe = StubProbe((t) async => successResult(t));
      final observer = RecordingObserver();
      final connection = InternetConnection(targets: [target], probe: probe, observer: observer);

      await connection.dispose();
      await connection.dispose();

      check(observer.events.whereType<DisposeEvent>()).length.equals(1);
    });
  });

  group('PrintingConnectivityObserver', () {
    test('is const-constructible with default name', () {
      const observer = PrintingConnectivityObserver();
      check(observer).isA<PrintingConnectivityObserver>();

      // Smoke-check: every method should be safely callable without
      // throwing. dart:developer.log writes to the runtime log channel —
      // there is no per-test assertion target, but the lack of a thrown
      // exception is the contract.
      observer
        ..onExternalTriggerFired()
        ..onCheckIntervalChanged(const Duration(seconds: 5), const Duration(seconds: 3))
        ..onDispose();
    });

    test('accepts a custom logger name', () {
      const observer = PrintingConnectivityObserver(name: 'my_app.connectivity');

      check(observer).isA<ConnectivityObserver>();
    });
  });
}
