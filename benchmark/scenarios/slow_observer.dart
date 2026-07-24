/// Scenario: slow observer — the headline benchmark.
///
/// Observer sleeps 50 ms per callback; check interval 100 ms. This measures the package's worst case
/// under a deliberately-misbehaving synchronous observer, and the numbers it produces are a property
/// of the *observer*, not something dispatch changes can fix: a Dart isolate is single-threaded, so
/// 50 ms of synchronous work blocks the event loop for 50 ms no matter which queue (direct call, microtask, event queue)
/// it was dispatched from. Expect `max_stall_microseconds` ≈ the observer's per-callback delay and
/// `blocked_duty_ratio` ≈ delay ÷ check interval (~0.5 here).
///
/// What the event-bus refactor *did* change is the check cadence: the next tick's timer is armed before
/// observer microtasks drain, so checks stay on-interval as long as per-tick observer work < the interval.
/// Cadence is visible via `observer_call_count` ÷ run duration.
///
/// Probe is a [FakeProbe] (instant) — we want to isolate observer behaviour from HTTP variance.
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
