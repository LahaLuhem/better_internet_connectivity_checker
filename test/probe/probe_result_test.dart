import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  final target = ProbeTarget(uri: Uri.parse('https://example.com'));

  group('ProbeResult.success', () {
    test('marks the result as successful with no error', () {
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

  group('ProbeResult.failure', () {
    test('marks the result as failed and forwards the captured error', () {
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

    test('allows omitting the error when the failure is a predicate mismatch', () {
      final result = ProbeResult.failure(
        target: target,
        responseTime: const Duration(milliseconds: 100),
      );

      check(result.isSuccess).isFalse();
      check(result.error).isNull();
    });
  });
}
