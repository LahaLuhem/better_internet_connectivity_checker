/// Scenario: slow observer — the headline benchmark.
///
/// Observer sleeps 50 ms per callback; check interval 100 ms. Pre-refactor,
/// the synchronous observer stalls the scheduler loop — sustained tick drift.
/// Post-refactor, the microtask-deferred event dispatch should keep drift at
/// the noise floor.
///
/// **The before/after chart for `max_drift_microseconds` from this scenario
/// is the PR's main exhibit.** Probe is a [FakeProbe] (instant) — we want to
/// isolate observer behaviour from HTTP variance.
library;

import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/fake_probe.dart';
import '../harness/memory_sampler.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';
import '../harness/slow_observer.dart';
import '../harness/tick_drift_meter.dart';

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
    probe: FakeProbe.alwaysSuccess(responseTime: Duration.zero),
    checkInterval: const Duration(milliseconds: 100),
    observer: observer,
  );

  final memorySampler = MemorySampler()..start();
  final driftMeter = TickDriftMeter()..start();

  var emissionCount = 0;
  final subscription = checker.onStatusChange.listen((_) => emissionCount++);

  forceGc();
  await Future<void>.delayed(Duration(seconds: args.durationSeconds));

  driftMeter.stop();
  memorySampler.stop();

  await subscription.cancel();
  await checker.dispose();

  final totalObserverCalls = observer.callCounts.values.fold<int>(0, (a, b) => a + b);

  writer.writeRecord(
    iteration: iteration,
    samples: {
      'rss_bytes': memorySampler.samples,
      'tick_drift_microseconds': driftMeter.drifts
          .map((d) => d.inMicroseconds)
          .toList(growable: false),
    },
    summary: {
      'max_drift_microseconds': driftMeter.maxDrift.inMicroseconds,
      'median_drift_microseconds': driftMeter.medianDrift.inMicroseconds,
      'p95_drift_microseconds': driftMeter.p95Drift.inMicroseconds,
      'emission_count': emissionCount,
      'observer_call_count': totalObserverCalls,
      'peak_rss_bytes': memorySampler.peakRss,
    },
  );
}
