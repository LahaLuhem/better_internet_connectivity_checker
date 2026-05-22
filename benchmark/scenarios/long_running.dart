/// Scenario: long-running stability.
///
/// Quiet-app shape (1 subscriber, default-ish interval, server always up),
/// but sampling memory more aggressively to detect leaks. Default
/// `--duration-seconds 10` makes this a smoke; pass `--duration-seconds 3600`
/// for the full hour bake.
///
/// The metric that matters: `rss_delta_bytes`. A non-zero (positive) delta
/// over a long run is a leak; zero or oscillating-around-baseline is healthy.
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

  final server = LocalHttpServer();
  await server.start();

  final checker = InternetConnection(
    targets: [ProbeTarget(uri: server.baseUri)],
    checkInterval: const Duration(seconds: 5),
  );

  // Sample every 250 ms — finer resolution for leak detection. For 1 h runs
  // that's ~14k samples (~120 KB of int data). Acceptable.
  final memorySampler = MemorySampler(interval: const Duration(milliseconds: 250))..start();
  final driftMeter = TickDriftMeter()..start();

  var emissionCount = 0;
  final subscription = checker.onStatusChange.listen((_) => emissionCount++);

  forceGc();
  await Future<void>.delayed(Duration(seconds: args.durationSeconds));

  driftMeter.stop();
  memorySampler.stop();

  await subscription.cancel();
  await checker.dispose();
  final requestCount = server.requestCount;
  await server.stop();

  // Approximate growth rate per minute — useful sanity check vs durationSeconds.
  final minutes = args.durationSeconds / 60.0;
  final rssGrowthPerMinute = minutes <= 0 ? 0.0 : memorySampler.rssDelta / minutes;

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'long_running',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );
  writer.writeRecord(
    iteration: args.iteration,
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
      'rss_growth_bytes_per_minute': rssGrowthPerMinute,
      'max_drift_microseconds': driftMeter.maxDrift.inMicroseconds,
      'p95_drift_microseconds': driftMeter.p95Drift.inMicroseconds,
      'emission_count': emissionCount,
      'http_request_count': requestCount,
      'duration_seconds': args.durationSeconds,
    },
  );
  await writer.close();
}
