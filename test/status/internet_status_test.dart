import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Reachable.fromResponseTime', () {
    test('reports good quality when no threshold configured', () {
      final status = Reachable.fromResponseTime(const Duration(seconds: 5), slowThreshold: null);

      check(status.quality).equals(ConnectionQuality.good);
      check(status.responseTime).equals(const Duration(seconds: 5));
    });

    test('reports good quality when response time is under threshold', () {
      final status = Reachable.fromResponseTime(
        const Duration(milliseconds: 100),
        slowThreshold: const Duration(milliseconds: 500),
      );

      check(status.quality).equals(ConnectionQuality.good);
    });

    test('reports slow quality when response time exceeds threshold', () {
      final status = Reachable.fromResponseTime(
        const Duration(milliseconds: 600),
        slowThreshold: const Duration(milliseconds: 500),
      );

      check(status.quality).equals(ConnectionQuality.slow);
    });

    test('boundary value (equal to threshold) is classified as good', () {
      final status = Reachable.fromResponseTime(
        const Duration(milliseconds: 500),
        slowThreshold: const Duration(milliseconds: 500),
      );

      check(status.quality).equals(ConnectionQuality.good);
    });
  });

  group('sealed pattern matching', () {
    test('exhaustive switch resolves Reachable', () {
      const InternetStatus status = Reachable(
        responseTime: Duration(milliseconds: 100),
        quality: ConnectionQuality.good,
      );
      final label = switch (status) {
        Reachable() => 'reachable',
        Unreachable() => 'unreachable',
      };

      check(label).equals('reachable');
    });

    test('exhaustive switch resolves Unreachable', () {
      const InternetStatus status = Unreachable(failedProbes: []);
      final label = switch (status) {
        Reachable() => 'reachable',
        Unreachable() => 'unreachable',
      };

      check(label).equals('unreachable');
    });
  });

  group('Reachable.toString', () {
    test('renders responseTime and quality in stable diagnostic form', () {
      const status = Reachable(
        responseTime: Duration(milliseconds: 250),
        quality: ConnectionQuality.good,
      );

      check(status.toString()).equals(
        'Reachable('
        'responseTime: 0:00:00.250000, '
        'quality: ConnectionQuality.good)',
      );
    });
  });

  group('Unreachable.toString', () {
    test('renders failedProbes in stable diagnostic form', () {
      const status = Unreachable(failedProbes: []);

      check(status.toString()).equals('Unreachable(failedProbes: [])');
    });

    test('includes each failed probe by its own toString', () {
      final target = ProbeTarget(uri: Uri.https('example.com'));
      final probe = ProbeResult.failure(target: target, responseTime: const Duration(seconds: 1));
      final status = Unreachable(failedProbes: [probe]);

      check(status.toString()).startsWith('Unreachable(failedProbes: [');
      check(status.toString()).contains('ProbeResult(');
    });
  });
}
