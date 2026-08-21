import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';

import '../support/bdd.dart';
import '../support/stub_probe.dart';

void main() {
  final t1 = ProbeTarget(uri: Uri.https('a.example.com'));
  final t2 = ProbeTarget(uri: Uri.https('b.example.com'));
  final t3 = ProbeTarget(uri: Uri.https('c.example.com'));

  feature('MinimumReachablePolicy', () {
    scenario('returns Reachable once enough probes succeed', () async {
      final probe = StubProbe((target) async {
        if (target == t3) {
          return ProbeResult.failure(
            target: target,
            responseTime: const Duration(milliseconds: 50),
          );
        }

        return ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 100));
      });

      final status = await const MinimumReachablePolicy(minimum: 2)
          .evaluate(targets: [t1, t2, t3], probe: probe, slowThreshold: null);

      check(status).isA<Reachable>();
    });

    scenario('reports the deciding success as the response time, not the fastest one', () async {
      final probe = StubProbe(
        (target) => target == t1
            ? Future.delayed(
                const Duration(milliseconds: 10),
                () => ProbeResult.success(
                  target: target,
                  responseTime: const Duration(milliseconds: 10),
                ),
              )
            : Future.delayed(
                const Duration(milliseconds: 60),
                () => ProbeResult.success(
                  target: target,
                  responseTime: const Duration(milliseconds: 300),
                ),
              ),
      );

      final status = await const MinimumReachablePolicy(minimum: 2)
          .evaluate(targets: [t1, t2], probe: probe, slowThreshold: null);

      check((status as Reachable).responseTime).equals(const Duration(milliseconds: 300));
    });

    scenario(
      'settles the moment the minimum is out of reach, without waiting for the rest',
      () async {
        final probe = StubProbe((target) {
          if (target == t3) {
            return Future.delayed(
              const Duration(seconds: 30),
              () => ProbeResult.success(target: target, responseTime: const Duration(seconds: 30)),
            );
          }

          return Future.value(
            ProbeResult.failure(target: target, responseTime: const Duration(milliseconds: 20)),
          );
        });

        final stopwatch = Stopwatch()..start();
        final status = await const MinimumReachablePolicy(minimum: 2)
            .evaluate(targets: [t1, t2, t3], probe: probe, slowThreshold: null);
        stopwatch.stop();

        check(status).isA<Unreachable>();
        check((status as Unreachable).failedProbes).length.equals(2);
        check(stopwatch.elapsed).isLessThan(const Duration(seconds: 1));
      },
    );

    // Deciding early means the list stops at the failure that settled it, three of four here.
    scenario('lists the failures that decided the verdict, not every target', () async {
      final t4 = ProbeTarget(uri: Uri.https('d.example.com'));
      final probe = StubProbe(
        (target) async =>
            ProbeResult.failure(target: target, responseTime: const Duration(milliseconds: 50)),
      );

      final status = await const MinimumReachablePolicy(minimum: 2)
          .evaluate(targets: [t1, t2, t3, t4], probe: probe, slowThreshold: null);

      check(status).isA<Unreachable>();
      check((status as Unreachable).failedProbes).length.equals(3);
    });

    scenario('trips an assert when the minimum exceeds the target list (dev-time check)', () {
      final probe = StubProbe((_) async => throw StateError('probe must not be invoked'));

      check(
        () =>
            const MinimumReachablePolicy(minimum: 3)
                .evaluate(targets: [t1, t2], probe: probe, slowThreshold: null),
      ).throws<AssertionError>();
    });

    scenario('classifies the deciding probe as slow when above threshold', () async {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 800)),
      );

      final status = await const MinimumReachablePolicy(
        minimum: 2,
      ).evaluate(targets: [t1, t2], probe: probe, slowThreshold: const Duration(milliseconds: 500));

      check((status as Reachable).quality).equals(.slow);
    });

    scenario('passes a cancelSignal to every probe', () async {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 10)),
      );

      await const MinimumReachablePolicy(minimum: 2)
          .evaluate(targets: [t1, t2], probe: probe, slowThreshold: null);

      check(probe.cancelSignalFor(t1)).isNotNull();
      check(probe.cancelSignalFor(t2)).isNotNull();
    });

    scenario("completes the stragglers' cancelSignal once the minimum is met", () async {
      final stragglerResult = Completer<ProbeResult>();
      final probe = StubProbe(
        (target) => target == t3
            ? stragglerResult.future
            : Future.value(
                ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 10)),
              ),
      );

      await const MinimumReachablePolicy(minimum: 2)
          .evaluate(targets: [t1, t2, t3], probe: probe, slowThreshold: null);

      await probe.cancelSignalFor(t3)!.timeout(const Duration(seconds: 1));

      stragglerResult.complete(
        ProbeResult.failure(target: t3, responseTime: const Duration(milliseconds: 100)),
      );
    });
  });
}
