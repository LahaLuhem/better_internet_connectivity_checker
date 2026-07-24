import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';

import '../support/bdd.dart';

void main() {
  final target = ProbeTarget(uri: Uri.https('example.com'));

  feature('ProbeResult.success', () {
    scenario('marks the result as successful with no error', () {
      final result = ProbeResult.success(
        target: target,
        responseTime: const Duration(milliseconds: 42),
      );

      check(result.isSuccess).isTrue();
      check(result.error).isNull();
      check(result.responseTime).equals(const Duration(milliseconds: 42));
      check(result.target).equals(target);
    });
  });

  feature('ProbeResult.failure', () {
    scenario('marks the result as failed and forwards the captured error', () {
      final error = Exception('boom');
      final result = ProbeResult.failure(
        target: target,
        responseTime: const Duration(milliseconds: 100),
        error: error,
      );

      check(result.isSuccess).isFalse();
      check(result.error).equals(error);
      check(result.responseTime).equals(const Duration(milliseconds: 100));
    });

    scenario('allows omitting the error when the failure is a predicate mismatch', () {
      final result = ProbeResult.failure(
        target: target,
        responseTime: const Duration(milliseconds: 100),
      );

      check(result.isSuccess).isFalse();
      check(result.error).isNull();
    });
  });

  feature('ProbeResult.toString', () {
    scenario('renders all fields in stable diagnostic form on success', () {
      final result = ProbeResult.success(
        target: target,
        responseTime: const Duration(milliseconds: 42),
      );

      check(result.toString()).equals(
        'ProbeResult('
        'target: $target, '
        'isSuccess: true, '
        'responseTime: 0:00:00.042000, '
        'error: null)',
      );
    });

    scenario('includes the captured error verbatim on failure', () {
      final error = Exception('boom');
      final result = ProbeResult.failure(
        target: target,
        responseTime: const Duration(milliseconds: 100),
        error: error,
      );

      check(result.toString()).contains('isSuccess: false');
      check(result.toString()).contains('error: $error');
    });
  });
}
