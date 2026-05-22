/// Scenario: quiet steady-state app.
///
/// One subscriber, configurable check interval (default 500 ms), local HTTP
/// server always-up. Measures the baseline cost of running [InternetConnection]
/// against a real-but-deterministic transport — RSS over time, tick drift,
/// emission count, dispose latency.
///
/// This is the "everything works" reference scenario. Any post-refactor
/// regression in steady-state cost shows up here first.
library;

import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/local_http_server.dart';
import '../harness/memory_sampler.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';
import '../harness/tick_drift_meter.dart';

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
    // Settle between iterations: forceGc drops young-gen pressure; the small
    // delay gives the event loop time to drain any deferred microtasks from
    // the previous iteration's dispose chain before we open the next checker.
    forceGc();
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

  final memorySampler = MemorySampler(interval: const Duration(milliseconds: 500))..start();
  final driftMeter = TickDriftMeter()..start();

  var emissionCount = 0;
  final subscription = checker.onStatusChange.listen((_) => emissionCount++);

  forceGc();
  // Let the scheduler tick for the configured duration.
  await Future<void>.delayed(Duration(seconds: args.durationSeconds));

  driftMeter.stop();
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
      'tick_drift_microseconds': driftMeter.drifts
          .map((d) => d.inMicroseconds)
          .toList(growable: false),
    },
    summary: {
      'peak_rss_bytes': memorySampler.peakRss,
      'min_rss_bytes': memorySampler.minRss,
      'rss_delta_bytes': memorySampler.rssDelta,
      'max_drift_microseconds': driftMeter.maxDrift.inMicroseconds,
      'median_drift_microseconds': driftMeter.medianDrift.inMicroseconds,
      'p95_drift_microseconds': driftMeter.p95Drift.inMicroseconds,
      'emission_count': emissionCount,
      'dispose_microseconds': disposeStopwatch.elapsedMicroseconds,
      'http_request_count': server.requestCount,
    },
  );
}
