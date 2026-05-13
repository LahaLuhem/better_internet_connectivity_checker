import 'dart:async';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/scaffolding.dart';
import 'package:ultimate_internet_connectivity_checker/ultimate_internet_connectivity_checker.dart';

import '_helpers/stub_probe.dart';

void main() {
  final target = ProbeTarget(uri: Uri.parse('https://example.com'));

  group('InternetConnection.checkOnce', () {
    test('runs the configured probe through the configured policy', () async {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 50)),
      );
      final connection = InternetConnection(targets: [target], probe: probe);
      addTearDown(connection.dispose);

      final status = await connection.checkOnce();

      check(status).isA<Reachable>();
    });

    test('does not populate lastStatus', () async {
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

  group('InternetConnection constructor', () {
    test('asserts when targets is empty (dev-time check)', () {
      check(() => InternetConnection(targets: const [])).throws<AssertionError>();
    });
  });

  group('onStatusChange', () {
    test('emits when status kind changes between ticks', () {
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

    test('does not re-emit when consecutive ticks share the same kind', () {
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

    test('emits when ConnectionQuality flips from good to slow', () {
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
        check((events.last as Reachable).quality).equals(ConnectionQuality.good);

        responseTime = const Duration(milliseconds: 800);
        async.elapse(const Duration(seconds: 5));
        check(events).length.equals(2);
        check((events.last as Reachable).quality).equals(ConnectionQuality.slow);

        unawaited(connection.dispose());
      });
    });
  });

  group('externalRecheckTrigger', () {
    test('forces a recheck on every emission', () {
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
  });

  group('setCheckInterval', () {
    test('reschedules subsequent ticks at the new interval', () {
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

        connection.setCheckInterval(const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 2));
        check(probeCalls).equals(2);

        async.elapse(const Duration(seconds: 2));
        check(probeCalls).equals(3);

        unawaited(connection.dispose());
      });
    });
  });
}
