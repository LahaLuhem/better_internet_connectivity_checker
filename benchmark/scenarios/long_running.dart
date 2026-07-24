/// Scenario: long-running stability.
///
/// Quiet-app shape (1 subscriber, default-ish interval, server always up), but sampling memory more
/// aggressively to detect leaks. Default `--duration-seconds 10` makes this a smoke. Pass `--duration-seconds 3600`
/// for the full hour bake.
///
/// The metric that matters: `rss_delta_bytes`. A non-zero (positive) delta over a long run is a leak.
/// Zero or oscillating-around-baseline is healthy.
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
    scenario: 'long_running',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  for (var i = 0; i < args.iterations; i++) {
    await _runIteration(args, iteration: i, writer: writer);
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
    checkInterval: const Duration(seconds: 5),
  );

  // Sample every 250 ms — finer resolution for leak detection. For 1 h runs
  // that's ~14k samples (~120 KB of int data). Acceptable.
  final memorySampler = MemorySampler(interval: const Duration(milliseconds: 250))..start();
  final stallMeter = EventLoopStallMeter()..start();

  var emissionCount = 0;
  final subscription = checker.onStatusChange.listen((_) => emissionCount++);

  forceGc();
  await Future<void>.delayed(Duration(seconds: args.durationSeconds));

  stallMeter.stop();
  memorySampler.stop();

  await subscription.cancel();
  await checker.dispose();
  final requestCount = server.requestCount;
  await server.stop();

  // Approximate growth rate per minute — useful sanity check vs durationSeconds.
  final minutes = args.durationSeconds / 60.0;
  final rssGrowthPerMinute = minutes <= 0 ? 0.0 : memorySampler.rssDelta / minutes;

  writer.writeRecord(
    iteration: iteration,
    samples: {
      'rss_bytes': memorySampler.samples,
      'stall_microseconds': stallMeter.stalls.map((d) => d.inMicroseconds).toList(growable: false),
    },
    summary: {
      'peak_rss_bytes': memorySampler.peakRss,
      'min_rss_bytes': memorySampler.minRss,
      'rss_delta_bytes': memorySampler.rssDelta,
      'rss_growth_bytes_per_minute': rssGrowthPerMinute,
      'max_stall_microseconds': stallMeter.maxStall.inMicroseconds,
      'total_blocked_microseconds': stallMeter.totalBlocked.inMicroseconds,
      'blocked_duty_ratio': stallMeter.blockedDutyRatio,
      'emission_count': emissionCount,
      'http_request_count': requestCount,
      'duration_seconds': args.durationSeconds,
    },
  );
}
