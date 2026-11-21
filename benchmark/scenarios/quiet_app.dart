/// Scenario: quiet steady-state app.
///
/// One subscriber, server always up. The baseline cost of simply having an [InternetConnection]
/// running, and the reference everything else gets read against. A steady-state regression lands here
/// first.
library;

import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/event_loop_stall_meter.dart';
import '../harness/local_http_server.dart';
import '../harness/memory_sampler.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'quiet_app',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  for (var i = 0; i < args.iterations; i++) {
    await _runIteration(args, iteration: i, writer: writer);
    // Let the previous iteration's dispose chain drain before the next checker opens.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  await writer.close();
}

Future<void> _runIteration(
  ScenarioArgs args, {
  required int iteration,
  required ResultWriter writer,
}) async {
  final server = LocalHttpServer();
  await server.start();

  final checker = InternetConnection(
    targets: [ProbeTarget(uri: server.baseUri)],
    checkInterval: const Duration(milliseconds: 500),
  );

  final memorySampler = MemorySampler()..start();
  final stallMeter = EventLoopStallMeter()..start();

  var emissionCount = 0;
  final subscription = checker.onStatusChange.listen((_) => emissionCount++);

  // Let the scheduler tick for the configured duration.
  await Future<void>.delayed(Duration(seconds: args.durationSeconds));

  stallMeter.stop();
  memorySampler.stop();

  await subscription.cancel();
  final disposeStopwatch = Stopwatch()..start();
  await checker.dispose();
  disposeStopwatch.stop();
  await server.stop();

  writer.writeRecord(
    iteration: iteration,
    samples: {
      'rss_bytes': memorySampler.samples,
      'stall_microseconds': stallMeter.stallMicroseconds,
    },
    summary: {
      'peak_rss_delta_bytes': memorySampler.peakRssDelta,
      'rss_delta_bytes': memorySampler.rssDelta,
      'max_stall_microseconds': stallMeter.maxStall.inMicroseconds,
      'total_blocked_microseconds': stallMeter.totalBlocked.inMicroseconds,
      'blocked_duty_ratio': stallMeter.blockedDutyRatio,
      'emission_count': emissionCount,
      'dispose_microseconds': disposeStopwatch.elapsedMicroseconds,
      'http_request_count': server.requestCount,
    },
  );
}
