import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('HttpHeadProbe', () {
    test('returns a successful result when the predicate accepts the response', () async {
      final client = MockClient((_) async => http.Response('', 200));
      final probe = HttpHeadProbe(client: client);
      final target = ProbeTarget(uri: Uri.https('example.com'));

      final result = await probe.probe(target);

      check(result.isSuccess).isTrue();
      check(result.error).isNull();
      check(result.target).equals(target);
    });

    test('returns a failed result when the predicate rejects the response', () async {
      final client = MockClient((_) async => http.Response('', 500));
      final probe = HttpHeadProbe(client: client);
      final target = ProbeTarget(uri: Uri.https('example.com'));

      final result = await probe.probe(target);

      check(result.isSuccess).isFalse();
      check(result.error).isNull();
    });

    test('captures exceptions raised by the underlying transport', () async {
      final boom = Exception('network down');
      final client = MockClient((_) async => throw boom);
      final probe = HttpHeadProbe(client: client);
      final target = ProbeTarget(uri: Uri.https('example.com'));

      final result = await probe.probe(target);

      check(result.isSuccess).isFalse();
      check(result.error).equals(boom);
    });

    test('issues an HTTP HEAD request with the target URI and headers', () async {
      late http.BaseRequest captured;
      final client = MockClient((request) async {
        captured = request;

        return http.Response('', 200);
      });
      final probe = HttpHeadProbe(client: client);
      final target = ProbeTarget(
        uri: Uri.https('example.com', '/ping'),
        headers: const {'X-Custom': 'yes'},
      );

      await probe.probe(target);

      check(captured.method).equals('HEAD');
      check(captured.url).equals(target.uri);
      check(captured.headers['x-custom']).equals('yes');
    });
  });
}
