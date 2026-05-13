import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:ultimate_internet_connectivity_checker/ultimate_internet_connectivity_checker.dart';

void main() {
  group('ProbeTarget defaults', () {
    test('uses a 3-second timeout', () {
      final target = ProbeTarget(uri: Uri.parse('https://example.com'));
      expect(target.timeout, const Duration(seconds: 3));
    });

    test('uses an empty headers map', () {
      final target = ProbeTarget(uri: Uri.parse('https://example.com'));
      expect(target.headers, isEmpty);
    });

    test('default predicate accepts HTTP 200 only', () {
      final target = ProbeTarget(uri: Uri.parse('https://example.com'));
      expect(target.isSuccess(http.Response('', 200)), isTrue);
      expect(target.isSuccess(http.Response('', 204)), isFalse);
      expect(target.isSuccess(http.Response('', 301)), isFalse);
      expect(target.isSuccess(http.Response('', 500)), isFalse);
    });
  });

  group('ProbeTarget customisation', () {
    test('respects a custom predicate', () {
      bool accept2xx(http.Response r) => r.statusCode >= 200 && r.statusCode < 300;
      final target = ProbeTarget(uri: Uri.parse('https://example.com'), isSuccess: accept2xx);
      expect(target.isSuccess(http.Response('', 204)), isTrue);
      expect(target.isSuccess(http.Response('', 301)), isFalse);
    });

    test('forwards a custom timeout and headers', () {
      const customHeaders = {'Authorization': 'Bearer x'};
      final target = ProbeTarget(
        uri: Uri.parse('https://example.com'),
        timeout: const Duration(seconds: 1),
        headers: customHeaders,
      );
      expect(target.timeout, const Duration(seconds: 1));
      expect(target.headers, customHeaders);
    });
  });
}
