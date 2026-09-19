/// Scenario: flapping network.
///
/// The server flips between 200 and 503 every 3 s while the checker runs every 1 s, so no toggle
/// slips past. Leans on the dedup path: 1 emission per toggle, never 2.
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
    scenario: 'flapping_network',
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
    checkInterval: const Duration(seconds: 1),
  );

  final memorySampler = MemorySampler()..start();
  final stallMeter = EventLoopStallMeter()..start();

  var emissionCount = 0;
  var reachableEmissions = 0;
  var unreachableEmissions = 0;
  final subscription = checker.onStatusChange.listen((status) {
    emissionCount++;
    switch (status) {
      case Reachable():
        reachableEmissions++;
      case Unreachable():
        unreachableEmissions++;
    }
  });

  // Flap the server every 3 seconds. Independent of the checker's tick clock.
  final toggleTimer = Timer.periodic(const Duration(seconds: 3), (_) => server.toggle());

  forceGc();
  await Future<void>.delayed(Duration(seconds: args.durationSeconds));

  toggleTimer.cancel();
  stallMeter.stop();
  memorySampler.stop();

  await subscription.cancel();
  await checker.dispose();
  final requestCount = server.requestCount;
  await server.stop();

  writer.writeRecord(
    iteration: iteration,
    samples: {
      'rss_bytes': memorySampler.samples,
      'stall_microseconds': stallMeter.stalls.map((d) => d.inMicroseconds).toList(growable: false),
    },
    summary: {
      'emission_count': emissionCount,
      'reachable_emissions': reachableEmissions,
      'unreachable_emissions': unreachableEmissions,
      'http_request_count': requestCount,
      'max_stall_microseconds': stallMeter.maxStall.inMicroseconds,
      'total_blocked_microseconds': stallMeter.totalBlocked.inMicroseconds,
      'blocked_duty_ratio': stallMeter.blockedDutyRatio,
      'peak_rss_bytes': memorySampler.peakRss,
      'rss_delta_bytes': memorySampler.rssDelta,
    },
  );
}
