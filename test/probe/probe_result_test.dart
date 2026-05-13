import 'package:test/test.dart';
import 'package:ultimate_internet_connectivity_checker/ultimate_internet_connectivity_checker.dart';

void main() {
  final target = ProbeTarget(uri: Uri.parse('https://example.com'));

  group('ProbeResult.success', () {
    test('marks the result as successful with no error', () {
      final result = ProbeResult.success(
        target: target,
        responseTime: const Duration(milliseconds: 42),
      );
      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(result.responseTime, const Duration(milliseconds: 42));
      expect(result.target, target);
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
      expect(result.isSuccess, isFalse);
      expect(result.error, error);
      expect(result.responseTime, const Duration(milliseconds: 100));
    });

    test('allows omitting the error when the failure is a predicate mismatch', () {
      final result = ProbeResult.failure(
        target: target,
        responseTime: const Duration(milliseconds: 100),
      );
      expect(result.isSuccess, isFalse);
      expect(result.error, isNull);
    });
  });
}
