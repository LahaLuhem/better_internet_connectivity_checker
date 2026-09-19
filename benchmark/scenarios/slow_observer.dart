/// Scenario: slow observer, the headline benchmark.
///
/// The observer sleeps 50 ms per callback against a 100 ms check interval. The numbers belong to the
/// observer, not to dispatch: one isolate means 50 ms of sync work parks the loop for 50 ms whichever
/// queue it came off. Expect `max_stall_microseconds` near the per-callback delay, and
/// `blocked_duty_ratio` near delay over interval, so roughly 0.5 here.
///
/// What the event-bus refactor did change is cadence. The next tick is armed before observer
/// microtasks drain, so checks stay on-interval while per-tick observer work stays under it. Read
/// that off `observer_call_count` over run duration.
///
/// The probe is an instant [FakeProbe], to keep HTTP variance out of it.
library;

import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/event_loop_stall_meter.dart';
import '../harness/fake_probe.dart';
import '../harness/memory_sampler.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';
import '../harness/slow_observer.dart';

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'slow_observer',
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
  final observer = SlowObserver();
  final checker = InternetConnection(
    targets: [ProbeTarget(uri: Uri.parse('http://127.0.0.1/fake'))],
    probe: FakeProbe.alwaysSuccess(responseTime: .zero),
    checkInterval: const Duration(milliseconds: 100),
  );
  attachObserver(checker.events, observer);

  final memorySampler = MemorySampler()..start();
  final stallMeter = EventLoopStallMeter()..start();

  var emissionCount = 0;
  final subscription = checker.onStatusChange.listen((_) => emissionCount++);

  forceGc();
  await Future<void>.delayed(Duration(seconds: args.durationSeconds));

  stallMeter.stop();
  memorySampler.stop();

  await subscription.cancel();
  await checker.dispose();

  final totalObserverCalls = observer.callCounts.values.fold<int>(0, (a, b) => a + b);

  writer.writeRecord(
    iteration: iteration,
    samples: {
      'rss_bytes': memorySampler.samples,
      'stall_microseconds': stallMeter.stalls.map((d) => d.inMicroseconds).toList(growable: false),
    },
    summary: {
      'max_stall_microseconds': stallMeter.maxStall.inMicroseconds,
      'total_blocked_microseconds': stallMeter.totalBlocked.inMicroseconds,
      'blocked_duty_ratio': stallMeter.blockedDutyRatio,
      'emission_count': emissionCount,
      'observer_call_count': totalObserverCalls,
      'peak_rss_bytes': memorySampler.peakRss,
    },
  );
}
