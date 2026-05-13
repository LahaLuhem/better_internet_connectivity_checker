import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:ultimate_internet_connectivity_checker/ultimate_internet_connectivity_checker.dart';

void main() {
  group('HttpHeadProbe', () {
    test('returns a successful result when the predicate accepts the response', () async {
      final client = MockClient((_) async => http.Response('', 200));
      final probe = HttpHeadProbe(client: client);
      final target = ProbeTarget(uri: Uri.parse('https://example.com'));

      final result = await probe.probe(target);

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(result.target, target);
    });

    test('returns a failed result when the predicate rejects the response', () async {
      final client = MockClient((_) async => http.Response('', 500));
      final probe = HttpHeadProbe(client: client);
      final target = ProbeTarget(uri: Uri.parse('https://example.com'));

      final result = await probe.probe(target);

      expect(result.isSuccess, isFalse);
      expect(result.error, isNull);
    });

    test('captures exceptions raised by the underlying transport', () async {
      final boom = Exception('network down');
      final client = MockClient((_) async => throw boom);
      final probe = HttpHeadProbe(client: client);
      final target = ProbeTarget(uri: Uri.parse('https://example.com'));

      final result = await probe.probe(target);

      expect(result.isSuccess, isFalse);
      expect(result.error, boom);
    });

    test('issues an HTTP HEAD request with the target URI and headers', () async {
      late http.BaseRequest captured;
      final client = MockClient((request) async {
        captured = request;

        return http.Response('', 200);
      });
      final probe = HttpHeadProbe(client: client);
      final target = ProbeTarget(
        uri: Uri.parse('https://example.com/ping'),
        headers: const {'X-Custom': 'yes'},
      );

      await probe.probe(target);

      expect(captured.method, 'HEAD');
      expect(captured.url, target.uri);
      expect(captured.headers['x-custom'], 'yes');
    });
  });
}
