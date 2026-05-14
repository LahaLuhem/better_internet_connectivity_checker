import 'dart:async';

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

  group('HttpHeadProbe cancellation', () {
    test('issues an AbortableRequest whose trigger fires when cancelSignal does', () async {
      final capturedRequest = Completer<http.BaseRequest>();
      final responseCompleter = Completer<http.StreamedResponse>();
      final client = MockClient.streaming((request, _) {
        capturedRequest.complete(request);

        return responseCompleter.future;
      });
      final probe = HttpHeadProbe(client: client);
      final cancelCompleter = Completer<void>();
      final target = ProbeTarget(uri: Uri.https('example.com'));

      unawaited(probe.probe(target, cancelSignal: cancelCompleter.future));

      final request = await capturedRequest.future;
      check(request).isA<http.AbortableRequest>();
      final abortable = request as http.AbortableRequest;
      check(abortable.abortTrigger).isNotNull();

      var triggered = false;
      unawaited(abortable.abortTrigger!.whenComplete(() => triggered = true));
      await Future<void>.delayed(Duration.zero);
      check(triggered).isFalse();

      cancelCompleter.complete();
      await Future<void>.delayed(Duration.zero);
      check(triggered).isTrue();

      responseCompleter.complete(http.StreamedResponse(const Stream.empty(), 200));
    });

    test('returns a failure quickly when cancelSignal fires before a response', () async {
      final client = MockClient.streaming((request, _) {
        final body = Completer<http.StreamedResponse>();
        final trigger = (request as http.AbortableRequest).abortTrigger;
        unawaited(
          trigger?.whenComplete(() {
            if (!body.isCompleted) {
              body.completeError(http.RequestAbortedException(request.url));
            }
          }),
        );

        return body.future;
      });
      final probe = HttpHeadProbe(client: client);
      final target = ProbeTarget(
        uri: Uri.https('example.com'),
        timeout: const Duration(seconds: 30),
      );
      final cancelCompleter = Completer<void>();
      Timer(const Duration(milliseconds: 50), cancelCompleter.complete);

      final stopwatch = Stopwatch()..start();
      final result = await probe.probe(target, cancelSignal: cancelCompleter.future);
      stopwatch.stop();

      check(result.isSuccess).isFalse();
      check(result.error).isA<http.RequestAbortedException>();
      check(stopwatch.elapsed).isLessThan(const Duration(seconds: 1));
    });
  });
}
