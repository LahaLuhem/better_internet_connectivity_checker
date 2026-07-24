/// Scenario: many subscribers.
///
/// Runs three sub-scenarios in sequence with N ∈ {1, 10, 100} subscribers on `onStatusChange`, each
/// emitting its own JSON record (shared scenario name; `subscriber_count` is the pivot). With `--iterations K`,
/// that's K × 3 records per invocation.
///
/// Captures the per-subscriber broadcast cost, which should scale linearly with N.
library;

import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/event_loop_stall_meter.dart';
import '../harness/fake_probe.dart';
import '../harness/memory_sampler.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

const _subscriberCounts = <int>[1, 10, 100];

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  // One writer file across all iterations × subscriber counts.
  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'many_subscribers',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  for (var i = 0; i < args.iterations; i++) {
    for (final subscriberCount in _subscriberCounts) {
      await _runOneConfig(
        subscriberCount: subscriberCount,
        durationSeconds: args.durationSeconds,
        iteration: i,
        writer: writer,
      );
      forceGc();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  await writer.close();
}

Future<void> _runOneConfig({
  required int subscriberCount,
  required int durationSeconds,
  required int iteration,
  required ResultWriter writer,
}) async {
  final checker = InternetConnection(
    targets: [ProbeTarget(uri: Uri.parse('http://127.0.0.1/fake'))],
    probe: FakeProbe.alwaysSuccess(responseTime: .zero),
    checkInterval: const Duration(milliseconds: 100),
  );

  final memorySampler = MemorySampler()..start();
  final stallMeter = EventLoopStallMeter()..start();

  // Each subscriber: count emissions it sees. Aggregate count = sum.
  final perSubscriberCounts = List<int>.filled(subscriberCount, 0);
  final subscriptions = <StreamSubscription<InternetStatus>>[
    for (var i = 0; i < subscriberCount; i++)
      checker.onStatusChange.listen((_) => perSubscriberCounts[i]++),
  ];

  forceGc();
  await Future<void>.delayed(Duration(seconds: durationSeconds));

  stallMeter.stop();
  memorySampler.stop();

  for (final sub in subscriptions) {
    await sub.cancel();
  }
  await checker.dispose();

  final totalDeliveries = perSubscriberCounts.fold<int>(0, (a, b) => a + b);
  final perSubscriberMedian = subscriberCount == 0 ? 0 : totalDeliveries ~/ subscriberCount;

  // The JSON `scenario` field is `many_subscribers` for every record produced here (set on the shared writer).
  // The `subscriber_count` summary key is the canonical pivot when comparing N=1 vs N=10 vs N=100 downstream.
  writer.writeRecord(
    iteration: iteration,
    samples: {
      'rss_bytes': memorySampler.samples,
      'stall_microseconds': stallMeter.stalls.map((d) => d.inMicroseconds).toList(growable: false),
    },
    summary: {
      'subscriber_count': subscriberCount,
      'total_deliveries': totalDeliveries,
      'per_subscriber_median_deliveries': perSubscriberMedian,
      'max_stall_microseconds': stallMeter.maxStall.inMicroseconds,
      'total_blocked_microseconds': stallMeter.totalBlocked.inMicroseconds,
      'blocked_duty_ratio': stallMeter.blockedDutyRatio,
      'peak_rss_bytes': memorySampler.peakRss,
      'rss_delta_bytes': memorySampler.rssDelta,
    },
  );
}
