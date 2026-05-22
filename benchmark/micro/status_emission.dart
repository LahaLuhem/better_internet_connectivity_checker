/// Micro-benchmark: cost of one `StreamController.add(InternetStatus)` with N
/// listeners.
///
/// Measures the broadcast-stream emission path in isolation — no probe, no
/// scheduler, no observer. With `--iterations K`, emits `K × 3` records
/// (three subscriber counts per iteration; `subscriber_count` is the pivot).
///
/// Uses a **synchronous** broadcast (`sync: true`). The production
/// `InternetConnection` uses async-default broadcast (events queue, deliver
/// on next microtask), where the producer pays a constant cost regardless
/// of N. Measuring async here would give the same number three times — no
/// signal. Sync broadcast forces in-line delivery, so the cost scales
/// linearly with N and the measurement reveals what one fan-out site costs
/// per subscriber. The async path can be re-derived as "sync minus per-
/// listener work" later.
library;

import 'dart:async';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

const _subscriberCounts = <int>[1, 10, 100];

final class _StatusEmissionBenchmark extends BenchmarkBase {
  _StatusEmissionBenchmark(this.subscriberCount) : super('status_emission_n$subscriberCount');

  final int subscriberCount;
  late StreamController<InternetStatus> _controller;
  late List<StreamSubscription<InternetStatus>> _subscriptions;
  late InternetStatus _payload;

  @override
  void setup() {
    _controller = StreamController<InternetStatus>.broadcast(sync: true);
    _subscriptions = [
      for (var i = 0; i < subscriberCount; i++) _controller.stream.listen(noopWithVal),
    ];
    _payload = const Reachable(
      responseTime: Duration(milliseconds: 10),
      quality: ConnectionQuality.good,
    );
  }

  @override
  void teardown() {
    // BenchmarkBase.teardown is sync — fire-and-forget the cancellations.
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    unawaited(_controller.close());
  }

  @override
  void run() => _controller.add(_payload);
}

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'status_emission',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  for (var i = 0; i < args.iterations; i++) {
    for (final subscriberCount in _subscriberCounts) {
      forceGc();
      final microseconds = _StatusEmissionBenchmark(subscriberCount).measure();
      writer.writeRecord(
        iteration: i,
        samples: {
          'microseconds_per_emission': [microseconds],
        },
        summary: {'subscriber_count': subscriberCount, 'microseconds_per_emission': microseconds},
      );
    }
  }

  await writer.close();
}
