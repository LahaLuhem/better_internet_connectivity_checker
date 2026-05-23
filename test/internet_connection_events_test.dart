import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/scaffolding.dart';

import '_helpers/stub_probe.dart';

void main() {
  final target = ProbeTarget(uri: Uri.https('example.com'));

  group('InternetConnection.events', () {
    test('emits CheckCompletedEvent for every periodic tick', () {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50)),
      );

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          checkInterval: const Duration(seconds: 5),
        );
        final events = <ConnectivityEvent>[];
        connection.events.listen(events.add);
        connection.onStatusChange.listen(noopWithVal);

        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 10))
          ..flushMicrotasks();

        final completed = events.whereType<CheckCompletedEvent>().toList();
        check(completed).length.equals(3);
        check(completed.first.result).isA<Reachable>();

        unawaited(connection.dispose());
        async.flushMicrotasks();
      });
    });

    test('emits StatusEmittedEvent only on deduped transitions', () {
      var reachable = false;
      final probe = StubProbe((target) async {
        if (reachable) {
          return ProbeResult.success(
            target: target,
            responseTime: const Duration(milliseconds: 100),
          );
        }

        return ProbeResult.failure(target: target, responseTime: const Duration(milliseconds: 100));
      });

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          checkInterval: const Duration(seconds: 5),
        );
        final events = <ConnectivityEvent>[];
        connection.events.listen(events.add);
        connection.onStatusChange.listen(noopWithVal);

        async.flushMicrotasks();
        reachable = true;
        async
          ..elapse(const Duration(seconds: 5))
          ..flushMicrotasks();

        final emissions = events.whereType<StatusEmittedEvent>().toList();
        check(emissions).length.equals(2);
        check(emissions.first.previous).isNull();
        check(emissions.first.next).isA<Unreachable>();
        check(emissions.last.previous).isA<Unreachable>();
        check(emissions.last.next).isA<Reachable>();

        unawaited(connection.dispose());
        async.flushMicrotasks();
      });
    });

    test('emits ExternalTriggerFiredEvent when the trigger fires', () {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50)),
      );
      final trigger = StreamController<void>.broadcast();
      addTearDown(trigger.close);

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          externalRecheckTrigger: trigger.stream,
          checkInterval: const Duration(seconds: 5),
        );
        final events = <ConnectivityEvent>[];
        connection.events.listen(events.add);
        connection.onStatusChange.listen(noopWithVal);

        async.flushMicrotasks();
        trigger.add(null);
        async.flushMicrotasks();

        check(events.whereType<ExternalTriggerFiredEvent>()).length.equals(1);

        unawaited(connection.dispose());
        async.flushMicrotasks();
      });
    });

    test('emits ExternalTriggerErrorEvent when the trigger errors', () {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50)),
      );
      final trigger = StreamController<void>.broadcast();
      addTearDown(trigger.close);

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          externalRecheckTrigger: trigger.stream,
          checkInterval: const Duration(seconds: 5),
        );
        final events = <ConnectivityEvent>[];
        connection.events.listen(events.add);
        connection.onStatusChange.listen(noopWithVal);

        async.flushMicrotasks();
        trigger.addError(StateError('boom'), StackTrace.current);
        async.flushMicrotasks();

        final errors = events.whereType<ExternalTriggerErrorEvent>().toList();
        check(errors).length.equals(1);
        check(errors.single.error).isA<StateError>();

        unawaited(connection.dispose());
        async.flushMicrotasks();
      });
    });

    test('emits CheckIntervalChangedEvent on setter assignment', () {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50)),
      );

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          checkInterval: const Duration(seconds: 5),
        );
        final events = <ConnectivityEvent>[];
        connection.events.listen(events.add);

        connection.checkInterval = const Duration(seconds: 7);
        async.flushMicrotasks();

        final changes = events.whereType<CheckIntervalChangedEvent>().toList();
        check(changes).length.equals(1);
        check(changes.single.previous).equals(const Duration(seconds: 5));
        check(changes.single.next).equals(const Duration(seconds: 7));

        unawaited(connection.dispose());
        async.flushMicrotasks();
      });
    });

    test('emits SlowThresholdChangedEvent on setter assignment', () {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50)),
      );

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          slowThreshold: const Duration(milliseconds: 500),
        );
        final events = <ConnectivityEvent>[];
        connection.events.listen(events.add);

        connection.slowThreshold = const Duration(milliseconds: 200);
        async.flushMicrotasks();

        final changes = events.whereType<SlowThresholdChangedEvent>().toList();
        check(changes).length.equals(1);
        check(changes.single.previous).equals(const Duration(milliseconds: 500));
        check(changes.single.next).equals(const Duration(milliseconds: 200));

        unawaited(connection.dispose());
        async.flushMicrotasks();
      });
    });

    test('emits DisposedEvent as the terminal event before the stream closes', () {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50)),
      );

      fakeAsync((async) {
        final connection = InternetConnection(targets: [target], probe: probe);
        final events = <ConnectivityEvent>[];
        var closed = false;
        connection.events.listen(events.add, onDone: () => closed = true);

        unawaited(connection.dispose());
        async.flushMicrotasks();

        check(events).isNotEmpty();
        check(events.last).isA<DisposedEvent>();
        check(closed).isTrue();
      });
    });

    test('emission is microtask-deferred — subscriber sees event after the caller frame', () {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50)),
      );

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          checkInterval: const Duration(seconds: 5),
        );
        final events = <ConnectivityEvent>[];
        connection.events.listen(events.add);

        connection.checkInterval = const Duration(seconds: 7);
        // Setter returned synchronously. The event has been queued but not
        // delivered to subscribers yet.
        check(events).isEmpty();

        async.flushMicrotasks();
        // After microtasks drain, the subscriber receives the event.
        check(events).length.equals(1);
        check(events.single).isA<CheckIntervalChangedEvent>();

        unawaited(connection.dispose());
        async.flushMicrotasks();
      });
    });
  });
}
