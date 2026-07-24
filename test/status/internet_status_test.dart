import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';

import '../support/bdd.dart';

void main() {
  feature('InternetStatus', () {
    // Quality is `good` unless a threshold is configured AND the response time strictly exceeds it.
    // A null threshold disables slow detection; equal-to-threshold stays good.
    scenarioOutline<({Duration responseTime, Duration? slowThreshold, ConnectionQuality quality})>(
      'Reachable.fromResponseTime classifies quality against the slow threshold',
      examples: const {
        'no threshold configured': (
          responseTime: Duration(seconds: 5),
          slowThreshold: null,
          quality: .good,
        ),
        'under threshold': (
          responseTime: Duration(milliseconds: 100),
          slowThreshold: Duration(milliseconds: 500),
          quality: .good,
        ),
        'over threshold': (
          responseTime: Duration(milliseconds: 600),
          slowThreshold: Duration(milliseconds: 500),
          quality: .slow,
        ),
        'equal to threshold (boundary)': (
          responseTime: Duration(milliseconds: 500),
          slowThreshold: Duration(milliseconds: 500),
          quality: .good,
        ),
      },
      outline: (example) {
        final status = Reachable.fromResponseTime(
          example.responseTime,
          slowThreshold: example.slowThreshold,
        );

        check(status.quality).equals(example.quality);
      },
    );

    scenario('Reachable.fromResponseTime preserves the response time it was given', () {
      final status = Reachable.fromResponseTime(const Duration(seconds: 5), slowThreshold: null);

      check(status.responseTime).equals(const Duration(seconds: 5));
    });

    scenario('the sealed hierarchy switches exhaustively onto Reachable', () {
      const InternetStatus status = Reachable(
        responseTime: Duration(milliseconds: 100),
        quality: .good,
      );

      final label = switch (status) {
        Reachable() => 'reachable',
        Unreachable() => 'unreachable',
      };

      check(label).equals('reachable');
    });

    scenario('the sealed hierarchy switches exhaustively onto Unreachable', () {
      const InternetStatus status = Unreachable(failedProbes: []);

      final label = switch (status) {
        Reachable() => 'reachable',
        Unreachable() => 'unreachable',
      };

      check(label).equals('unreachable');
    });

    scenario('Reachable.toString renders responseTime and quality in stable diagnostic form', () {
      const status = Reachable(responseTime: Duration(milliseconds: 250), quality: .good);

      check(status.toString()).equals(
        'Reachable('
        'responseTime: 0:00:00.250000, '
        'quality: ConnectionQuality.good)',
      );
    });

    scenario('Unreachable.toString renders an empty failedProbes list', () {
      const status = Unreachable(failedProbes: []);

      check(status.toString()).equals('Unreachable(failedProbes: [])');
    });

    scenario('Unreachable.toString includes each failed probe by its own toString', () {
      final target = ProbeTarget(uri: Uri.https('example.com'));
      final probe = ProbeResult.failure(target: target, responseTime: const Duration(seconds: 1));
      final status = Unreachable(failedProbes: [probe]);

      check(status.toString())
        ..startsWith('Unreachable(failedProbes: [')
        ..contains('ProbeResult(');
    });
  });
}
