import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../_helpers/stub_probe.dart';

void main() {
  final t1 = ProbeTarget(uri: Uri.https('a.example.com'));
  final t2 = ProbeTarget(uri: Uri.https('b.example.com'));

  group('AnyReachablePolicy.evaluate', () {
    test('returns Reachable when at least one probe succeeds', () async {
      final probe = StubProbe((target) async {
        if (target == t1) {
          return ProbeResult.failure(
            target: target,
            responseTime: const Duration(milliseconds: 50),
          );
        }

        return ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 100));
      });

      final status = await const AnyReachablePolicy().evaluate(
        targets: [t1, t2],
        probe: probe,
        slowThreshold: null,
      );

      check(status).isA<Reachable>();
      check((status as Reachable).responseTime).equals(const Duration(milliseconds: 100));
    });

    test('returns Unreachable carrying every failure when none succeed', () async {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.failure(target: target, responseTime: const Duration(milliseconds: 200)),
      );

      final status = await const AnyReachablePolicy().evaluate(
        targets: [t1, t2],
        probe: probe,
        slowThreshold: null,
      );

      check(status).isA<Unreachable>();
      check((status as Unreachable).failedProbes).length.equals(2);
    });

    test('returns on first success without waiting for slow pending probes', () async {
      final probe = StubProbe((target) {
        if (target == t1) {
          return Future.delayed(
            const Duration(milliseconds: 10),
            () =>
                ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 10)),
          );
        }

        return Future.delayed(
          const Duration(seconds: 30),
          () => ProbeResult.success(target: target, responseTime: const Duration(seconds: 30)),
        );
      });

      final stopwatch = Stopwatch()..start();
      final status = await const AnyReachablePolicy().evaluate(
        targets: [t1, t2],
        probe: probe,
        slowThreshold: null,
      );
      stopwatch.stop();

      check(status).isA<Reachable>();
      check(stopwatch.elapsed).isLessThan(const Duration(seconds: 1));
    });

    test('classifies the winning probe as slow when above threshold', () async {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 800)),
      );

      final status = await const AnyReachablePolicy().evaluate(
        targets: [t1],
        probe: probe,
        slowThreshold: const Duration(milliseconds: 500),
      );

      check((status as Reachable).quality).equals(ConnectionQuality.slow);
    });

    test('returns Unreachable with no failures for an empty target list', () async {
      final probe = StubProbe((_) async => fail('probe must not be invoked'));

      final status = await const AnyReachablePolicy().evaluate(
        targets: const [],
        probe: probe,
        slowThreshold: null,
      );

      check(status).isA<Unreachable>();
      check((status as Unreachable).failedProbes).isEmpty();
    });
  });
}
