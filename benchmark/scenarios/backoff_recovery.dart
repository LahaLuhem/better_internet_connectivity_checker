/// Scenario: backoff recovery.
///
/// One outage-then-recovery timeline, run twice per iteration: once on the default
/// [FixedIntervalSchedule], once on [ExponentialBackoffSchedule]. Both arms see the same local
/// server going 503 then 200 at the same offsets, so the pair of numbers is the trade the backoff
/// schedule actually makes: fewer probes while the connection is down, against a later recovery
/// signal once it returns.
library;

import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/event_loop_stall_meter.dart';
import '../harness/local_http_server.dart';
import '../harness/memory_sampler.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

/// Base interval for both arms, so the only difference between them is the schedule.
const _baseInterval = Duration(milliseconds: 500);

/// Ceiling for the backoff arm. Two rungs above the base, so the ladder flattens inside a short
/// outage rather than running off the end of the window.
const _maxBackoffDelay = Duration(seconds: 2);

/// Share of one arm's wall clock spent with the server down. The rest is the window in which
/// recovery has to be noticed, and it has to stay comfortably wider than [_maxBackoffDelay].
const _outageFraction = 0.6;

typedef _ArmResult = ({
  int outageRequestCount,
  Duration recoveryLatency,
  bool didRecover,
  int emissionCount,
});

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'backoff_recovery',
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
  // Half the budget per arm; they run back to back so neither competes for the event loop.
  final armDuration = Duration(seconds: args.durationSeconds) ~/ 2;

  final memorySampler = MemorySampler()..start();
  final stallMeter = EventLoopStallMeter()..start();

  forceGc();
  final fixedArm = await _runArm(schedule: const FixedIntervalSchedule(), duration: armDuration);
  final backoffArm = await _runArm(
    schedule: const ExponentialBackoffSchedule(maxDelay: _maxBackoffDelay),
    duration: armDuration,
  );

  stallMeter.stop();
  memorySampler.stop();

  writer.writeRecord(
    iteration: iteration,
    samples: {
      'rss_bytes': memorySampler.samples,
      'stall_microseconds': stallMeter.stalls.map((d) => d.inMicroseconds).toList(growable: false),
    },
    summary: {
      'fixed_outage_request_count': fixedArm.outageRequestCount,
      'backoff_outage_request_count': backoffArm.outageRequestCount,
      'probe_savings_ratio': _savingsRatio(
        fixed: fixedArm.outageRequestCount,
        backoff: backoffArm.outageRequestCount,
      ),
      'fixed_recovery_latency_microseconds': fixedArm.recoveryLatency.inMicroseconds,
      'backoff_recovery_latency_microseconds': backoffArm.recoveryLatency.inMicroseconds,
      // 0 marks an arm that never saw recovery inside its window, which makes its latency a
      // floor rather than a measurement. Filter on these before trusting the pair.
      'fixed_did_recover': fixedArm.didRecover ? 1 : 0,
      'backoff_did_recover': backoffArm.didRecover ? 1 : 0,
      'fixed_emission_count': fixedArm.emissionCount,
      'backoff_emission_count': backoffArm.emissionCount,
      'max_stall_microseconds': stallMeter.maxStall.inMicroseconds,
      'total_blocked_microseconds': stallMeter.totalBlocked.inMicroseconds,
      'blocked_duty_ratio': stallMeter.blockedDutyRatio,
      'peak_rss_bytes': memorySampler.peakRss,
      'rss_delta_bytes': memorySampler.rssDelta,
    },
  );
}

Future<_ArmResult> _runArm({required CheckSchedule schedule, required Duration duration}) async {
  final outage = Duration(microseconds: (duration.inMicroseconds * _outageFraction).round());
  final recoveryWindow = duration - outage;

  final server = LocalHttpServer();
  await server.start();
  server.setDown();

  final checker = InternetConnection(
    targets: [ProbeTarget(uri: server.baseUri)],
    checkInterval: _baseInterval,
    schedule: schedule,
  );

  final sinceRecovery = Stopwatch();
  Duration? recoveryLatency;
  var emissionCount = 0;
  final subscription = checker.onStatusChange.listen((status) {
    emissionCount++;
    if (status is Reachable && sinceRecovery.isRunning && recoveryLatency == null) {
      recoveryLatency = sinceRecovery.elapsed;
    }
  });

  await Future<void>.delayed(outage);
  final outageRequestCount = server.requestCount;

  server.setUp();
  sinceRecovery.start();
  await Future<void>.delayed(recoveryWindow);

  await subscription.cancel();
  await checker.dispose();
  await server.stop();

  return (
    outageRequestCount: outageRequestCount,
    // An arm that never recovered reports the window as a floor; `didRecover` says which it is.
    recoveryLatency: recoveryLatency ?? recoveryWindow,
    didRecover: recoveryLatency != null,
    emissionCount: emissionCount,
  );
}

double _savingsRatio({required int fixed, required int backoff}) =>
    fixed == 0 ? 0 : (fixed - backoff) / fixed;
