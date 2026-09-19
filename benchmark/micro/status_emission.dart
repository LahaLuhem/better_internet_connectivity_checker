/// Micro-benchmark: one `StreamController.add(InternetStatus)` at N listeners. No probe, no
/// scheduler, no observer. Three subscriber counts per iteration, pivoted on `subscriber_count`.
///
/// Synchronous broadcast on purpose. Production uses the async default, where the producer's cost
/// doesn't move with N, so measuring that here would print the same number 3 times. Sync delivery
/// fans out in line, which is what makes the per-subscriber cost visible.
library;

import 'dart:async';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

const _subscriberCounts = [1, 10, 25, 50, 100];

final class _StatusEmission extends BenchmarkBase {
  final int subscriberCount;

  new(this.subscriberCount) : super('status_emission_n$subscriberCount');

  late StreamController<InternetStatus> _controller;
  late List<StreamSubscription<InternetStatus>> _subscriptions;
  late InternetStatus _payload;

  @override
  void setup() {
    _controller = StreamController<InternetStatus>.broadcast(sync: true);
    _subscriptions = [
      for (var i = 0; i < subscriberCount; i++) _controller.stream.listen(noopWithVal),
    ];
    _payload = const Reachable(responseTime: Duration(milliseconds: 10), quality: .good);
  }

  @override
  void teardown() {
    // BenchmarkBase.teardown is sync, so fire-and-forget the cancellations.
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
      final microseconds = _StatusEmission(subscriberCount).measure();
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
