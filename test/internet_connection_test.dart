import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/scaffolding.dart';

import 'support/bdd.dart';
import 'support/recording_observer.dart';
import 'support/stub_probe.dart';

void main() {
  final target = ProbeTarget(uri: Uri.https('example.com'));

  feature('InternetConnection.checkOnce', () {
    scenario('runs the configured probe through the configured policy', () async {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50)),
      );
      final connection = InternetConnection(targets: [target], probe: probe);
      addTearDown(connection.dispose);

      final status = await connection.checkOnce();

      check(status).isA<Reachable>();
    });

    scenario('does not populate lastStatus', () async {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50)),
      );
      final connection = InternetConnection(targets: [target], probe: probe);
      addTearDown(connection.dispose);

      await connection.checkOnce();

      check(connection.lastStatus).isNull();
    });
  });

  feature('InternetConnection constructor', () {
    scenario('asserts when targets is empty (dev-time check)', () {
      check(() => InternetConnection(targets: const [])).throws<AssertionError>();
    });

    scenario('constructs with default probe and disposes cleanly', () async {
      // Exercises the `probe ?? HttpProbe.head()` fallback. We never invoke
      // `checkOnce` here because the default probe would hit the public
      // internet; we only want to verify construct-and-dispose is leak-free.
      final connection = InternetConnection();

      await connection.dispose();
    });

    scenario('checkInterval reflects the configured value', () {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50)),
      );
      final connection = InternetConnection(
        targets: [target],
        probe: probe,
        checkInterval: const Duration(seconds: 7),
      );
      addTearDown(connection.dispose);

      check(connection.checkInterval).equals(const Duration(seconds: 7));
    });
  });

  feature('InternetConnection.onStatusChange', () {
    scenario('emits when status kind changes between ticks', () {
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
        final events = <InternetStatus>[];
        connection.onStatusChange.listen(events.add);

        async.flushMicrotasks();
        check(events).length.equals(1);
        check(events.single).isA<Unreachable>();

        reachable = true;
        async.elapse(const Duration(seconds: 5));
        check(events).length.equals(2);
        check(events.last).isA<Reachable>();

        unawaited(connection.dispose());
      });
    });

    scenario('does not re-emit when consecutive ticks share the same kind', () {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.failure(target: target, responseTime: const Duration(milliseconds: 100)),
      );

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          checkInterval: const Duration(seconds: 5),
        );
        final events = <InternetStatus>[];
        connection.onStatusChange.listen(events.add);

        async.flushMicrotasks();
        check(events.first).isA<Unreachable>();

        async
          ..elapse(const Duration(seconds: 5))
          ..elapse(const Duration(seconds: 5))
          ..elapse(const Duration(seconds: 5));

        check(events).length.equals(1);

        unawaited(connection.dispose());
      });
    });

    scenario('resets timer and lastStatus when the last subscriber cancels', () {
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
        final sub = connection.onStatusChange.listen(noopWithVal);
        async.flushMicrotasks();
        check(connection.lastStatus).isA<Reachable>();

        unawaited(sub.cancel());
        async.flushMicrotasks();

        check(connection.lastStatus).isNull();

        unawaited(connection.dispose());
      });
    });

    scenario('emits when ConnectionQuality flips from good to slow', () {
      var responseTime = const Duration(milliseconds: 100);
      final probe = StubProbe(
        (target) async => ProbeResult.success(target: target, responseTime: responseTime),
      );

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          checkInterval: const Duration(seconds: 5),
          slowThreshold: const Duration(milliseconds: 500),
        );
        final events = <InternetStatus>[];
        connection.onStatusChange.listen(events.add);

        async.flushMicrotasks();
        check(events).length.equals(1);
        check((events.last as Reachable).quality).equals(.good);

        responseTime = const Duration(milliseconds: 800);
        async.elapse(const Duration(seconds: 5));
        check(events).length.equals(2);
        check((events.last as Reachable).quality).equals(.slow);

        unawaited(connection.dispose());
      });
    });
  });

  feature('InternetConnection.slowThreshold setter', () {
    scenario('mutates the threshold and applies it at the next check', () {
      const responseTime = Duration(milliseconds: 100);
      final probe = StubProbe(
        (target) async => ProbeResult.success(target: target, responseTime: responseTime),
      );

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          checkInterval: const Duration(seconds: 5),
          slowThreshold: const Duration(milliseconds: 500),
        );
        final events = <InternetStatus>[];
        connection.onStatusChange.listen(events.add);

        async.flushMicrotasks();
        check((events.last as Reachable).quality).equals(.good);

        // Tighten the threshold below the (fixed) response time.
        connection.slowThreshold = const Duration(milliseconds: 50);
        check(connection.slowThreshold).equals(const Duration(milliseconds: 50));

        async.elapse(const Duration(seconds: 5));
        check((events.last as Reachable).quality).equals(.slow);

        unawaited(connection.dispose());
      });
    });

    scenario('preserves lastStatus so the next emission carries a non-null previous', () {
      // Regression for the live-stream example: rebuilding the connection
      // on every slider release lost `_lastStatus`, causing the next
      // emission's observer payload to report `previous = null`. The
      // setter must mutate in place and keep history intact.
      const responseTime = Duration(milliseconds: 100);
      final probe = StubProbe(
        (target) async => ProbeResult.success(target: target, responseTime: responseTime),
      );

      fakeAsync((async) {
        final observer = RecordingObserver();
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          checkInterval: const Duration(seconds: 5),
          slowThreshold: const Duration(milliseconds: 500),
        );
        attachObserver(connection.events, observer);
        connection.onStatusChange.listen(noopWithVal);

        async.flushMicrotasks();
        check(connection.lastStatus).isA<Reachable>();

        // Tighten the threshold so the next check flips quality.
        connection.slowThreshold = const Duration(milliseconds: 50);
        // lastStatus is the pre-change observation and must survive.
        check(connection.lastStatus).isA<Reachable>();

        async.elapse(const Duration(seconds: 5));

        final transitions = observer.events.whereType<StatusChangeEmitted>().toList();
        // Two transitions: the initial good (previous null) and the
        // good -> slow flip (previous must be the good Reachable, NOT
        // null).
        check(transitions).length.equals(2);
        check(transitions.last.previous)
          ..isNotNull()
          ..isA<Reachable>();

        unawaited(connection.dispose());
      });
    });

    scenario('null disables slow classification', () async {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 800)),
      );
      final connection = InternetConnection(
        targets: [target],
        probe: probe,
        slowThreshold: const Duration(milliseconds: 100),
      );
      addTearDown(connection.dispose);

      connection.slowThreshold = null;
      check(connection.slowThreshold).isNull();

      final status = await connection.checkOnce();
      check((status as Reachable).quality).equals(.good);
    });
  });

  feature('InternetConnection.externalRecheckTrigger', () {
    scenario('forces a recheck on every emission', () {
      var probeCalls = 0;
      final probe = StubProbe((target) async {
        probeCalls += 1;

        return ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50));
      });
      final trigger = StreamController<void>.broadcast();
      addTearDown(trigger.close);

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          externalRecheckTrigger: trigger.stream,
          checkInterval: const Duration(hours: 1),
        );
        final events = <InternetStatus>[];
        connection.onStatusChange.listen(events.add);

        async.flushMicrotasks();
        check(probeCalls).equals(1);

        trigger.add(null);
        async.flushMicrotasks();
        check(probeCalls).equals(2);

        trigger.add(null);
        async.flushMicrotasks();
        check(probeCalls).equals(3);

        unawaited(connection.dispose());
      });
    });

    scenario('swallows errors emitted on the external trigger stream', () {
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
          checkInterval: const Duration(hours: 1),
        );
        final statusErrors = <Object>[];
        connection.onStatusChange.listen(noopWithVal, onError: statusErrors.add);

        async.flushMicrotasks();

        trigger.addError(Exception('boom'));
        async.flushMicrotasks();

        check(statusErrors).isEmpty();

        unawaited(connection.dispose());
      });
    });
  });

  feature('InternetConnection.checkInterval setter', () {
    scenario('reschedules subsequent ticks at the new interval', () {
      var probeCalls = 0;
      final probe = StubProbe((target) async {
        probeCalls += 1;

        return ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50));
      });

      fakeAsync((async) {
        final connection = InternetConnection(
          targets: [target],
          probe: probe,
          checkInterval: const Duration(hours: 1),
        );
        final events = <InternetStatus>[];
        connection.onStatusChange.listen(events.add);

        async.flushMicrotasks();
        check(probeCalls).equals(1);

        connection.checkInterval = const Duration(seconds: 2);
        async.elapse(const Duration(seconds: 2));
        check(probeCalls).equals(2);

        async.elapse(const Duration(seconds: 2));
        check(probeCalls).equals(3);

        unawaited(connection.dispose());
      });
    });
  });
}
