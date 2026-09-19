/// Scenario: trigger storm.
///
/// The external trigger fires 100 times a second, which is what a phone flapping between wifi and
/// cell looks like coming out of `connectivity_plus`.
///
/// The contract: an in-flight check isn't preempted, and each trigger resets the next scheduled tick.
/// A pile of extra emissions means coalescing regressed.
library;

import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/event_loop_stall_meter.dart';
import '../harness/fake_probe.dart';
import '../harness/memory_sampler.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'trigger_storm',
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
  final triggerController = StreamController<void>.broadcast();
  final checker = InternetConnection(
    targets: [ProbeTarget(uri: Uri.parse('http://127.0.0.1/fake'))],
    probe: FakeProbe.alwaysSuccess(responseTime: .zero),
    checkInterval: const Duration(seconds: 30), // long: triggers drive the rechecks
    externalRecheckTrigger: triggerController.stream,
  );

  final memorySampler = MemorySampler()..start();
  final stallMeter = EventLoopStallMeter()..start();

  var emissionCount = 0;
  final subscription = checker.onStatusChange.listen((_) => emissionCount++);

  // 100 triggers per second = 1 trigger every 10 ms.
  var triggerCount = 0;
  final stormTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
    triggerController.add(null);
    triggerCount++;
  });

  forceGc();
  await Future<void>.delayed(Duration(seconds: args.durationSeconds));

  stormTimer.cancel();
  stallMeter.stop();
  memorySampler.stop();

  await subscription.cancel();
  await triggerController.close();
  await checker.dispose();

  writer.writeRecord(
    iteration: iteration,
    samples: {
      'rss_bytes': memorySampler.samples,
      'stall_microseconds': stallMeter.stalls.map((d) => d.inMicroseconds).toList(growable: false),
    },
    summary: {
      'trigger_fire_count': triggerCount,
      'emission_count': emissionCount,
      // The ratio surfaces whether triggers are coalesced (low ratio) or
      // each trigger does work end-to-end (ratio ≈ 1, a regression).
      'emissions_per_trigger': emissionCount / (triggerCount == 0 ? 1 : triggerCount),
      'max_stall_microseconds': stallMeter.maxStall.inMicroseconds,
      'total_blocked_microseconds': stallMeter.totalBlocked.inMicroseconds,
      'blocked_duty_ratio': stallMeter.blockedDutyRatio,
      'peak_rss_bytes': memorySampler.peakRss,
      'rss_delta_bytes': memorySampler.rssDelta,
    },
  );
}
