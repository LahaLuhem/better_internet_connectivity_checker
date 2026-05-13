import 'package:test/test.dart';
import 'package:ultimate_internet_connectivity_checker/ultimate_internet_connectivity_checker.dart';

import '../_helpers/stub_probe.dart';

void main() {
  final t1 = ProbeTarget(uri: Uri.parse('https://a.example.com'));
  final t2 = ProbeTarget(uri: Uri.parse('https://b.example.com'));

  group('AllReachablePolicy.evaluate', () {
    test('returns Reachable only when every probe succeeds', () async {
      final probe = StubProbe(
        (target) async =>
            ProbeResult.success(target: target, responseTime: const Duration(milliseconds: 100)),
      );

      final status = await const AllReachablePolicy().evaluate(
        targets: [t1, t2],
        probe: probe,
        slowThreshold: null,
      );

      expect(status, isA<Reachable>());
    });

    test('returns Unreachable when any probe fails', () async {
      final probe = StubProbe((target) async {
        if (target == t1) {
          return ProbeResult.success(
            target: target,
            responseTime: const Duration(milliseconds: 100),
          );
        }

        return ProbeResult.failure(target: target, responseTime: const Duration(milliseconds: 50));
      });

      final status = await const AllReachablePolicy().evaluate(
        targets: [t1, t2],
        probe: probe,
        slowThreshold: null,
      );

      expect(status, isA<Unreachable>());
      final unreachable = status as Unreachable;
      expect(unreachable.failedProbes, hasLength(1));
      expect(unreachable.failedProbes.first.target, t2);
    });

    test('reports the slowest successful probe time on Reachable', () async {
      final probe = StubProbe((target) async {
        final delay = target == t1
            ? const Duration(milliseconds: 100)
            : const Duration(milliseconds: 500);

        return ProbeResult.success(target: target, responseTime: delay);
      });

      final status = await const AllReachablePolicy().evaluate(
        targets: [t1, t2],
        probe: probe,
        slowThreshold: null,
      );

      expect((status as Reachable).responseTime, const Duration(milliseconds: 500));
    });

    test('classifies as slow when the slowest probe exceeds threshold', () async {
      final probe = StubProbe((target) async {
        final delay = target == t1
            ? const Duration(milliseconds: 100)
            : const Duration(milliseconds: 800);

        return ProbeResult.success(target: target, responseTime: delay);
      });

      final status = await const AllReachablePolicy().evaluate(
        targets: [t1, t2],
        probe: probe,
        slowThreshold: const Duration(milliseconds: 500),
      );

      expect((status as Reachable).quality, ConnectionQuality.slow);
    });

    test('returns Unreachable with no failures for an empty target list', () async {
      final probe = StubProbe((_) async => fail('probe must not be invoked'));

      final status = await const AllReachablePolicy().evaluate(
        targets: const [],
        probe: probe,
        slowThreshold: null,
      );

      expect(status, isA<Unreachable>());
      expect((status as Unreachable).failedProbes, isEmpty);
    });
  });
}
