/// Scenario: flapping network.
///
/// Local HTTP server toggles between "up" (200) and "down" (503) every 3
/// seconds. The checker runs at 1 s interval against it, so each toggle is
/// observed within the next tick. Measures the dedup + emission path under
/// genuine status churn: every toggle should produce exactly one emission
/// (Reachable ↔ Unreachable).
///
/// Verifies the dedup contract holds under realistic transition rates. After
/// the refactor, the same metrics should hold — no regression in emission
/// count, no spurious duplicate emissions.
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
    checkInterval: const Duration(seconds: 1),
  );

  final memorySampler = MemorySampler()..start();
  final driftMeter = TickDriftMeter()..start();

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
  driftMeter.stop();
  memorySampler.stop();

  await subscription.cancel();
  await checker.dispose();
  final requestCount = server.requestCount;
  await server.stop();

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'flapping_network',
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
      'emission_count': emissionCount,
      'reachable_emissions': reachableEmissions,
      'unreachable_emissions': unreachableEmissions,
      'http_request_count': requestCount,
      'max_drift_microseconds': driftMeter.maxDrift.inMicroseconds,
      'p95_drift_microseconds': driftMeter.p95Drift.inMicroseconds,
      'peak_rss_bytes': memorySampler.peakRss,
      'rss_delta_bytes': memorySampler.rssDelta,
    },
  );
  await writer.close();
}
