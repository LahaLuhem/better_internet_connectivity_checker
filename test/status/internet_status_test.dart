import 'package:test/test.dart';
import 'package:ultimate_internet_connectivity_checker/ultimate_internet_connectivity_checker.dart';

void main() {
  group('Reachable.fromResponseTime', () {
    test('reports good quality when no threshold configured', () {
      final status = Reachable.fromResponseTime(const Duration(seconds: 5), slowThreshold: null);
      expect(status.quality, ConnectionQuality.good);
      expect(status.responseTime, const Duration(seconds: 5));
    });

    test('reports good quality when response time is under threshold', () {
      final status = Reachable.fromResponseTime(
        const Duration(milliseconds: 100),
        slowThreshold: const Duration(milliseconds: 500),
      );
      expect(status.quality, ConnectionQuality.good);
    });

    test('reports slow quality when response time exceeds threshold', () {
      final status = Reachable.fromResponseTime(
        const Duration(milliseconds: 600),
        slowThreshold: const Duration(milliseconds: 500),
      );
      expect(status.quality, ConnectionQuality.slow);
    });

    test('boundary value (equal to threshold) is classified as good', () {
      final status = Reachable.fromResponseTime(
        const Duration(milliseconds: 500),
        slowThreshold: const Duration(milliseconds: 500),
      );
      expect(status.quality, ConnectionQuality.good);
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
      expect(label, 'reachable');
    });

    test('exhaustive switch resolves Unreachable', () {
      const InternetStatus status = Unreachable(failedProbes: []);
      final label = switch (status) {
        Reachable() => 'reachable',
        Unreachable() => 'unreachable',
      };
      expect(label, 'unreachable');
    });
  });
}
