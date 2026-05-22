/// Micro-benchmark: cost of one `InternetConnection.checkOnce()` against an
/// instant fake probe.
///
/// Isolates the coordinator's per-check cost (probe call → policy aggregation
/// → result construction) from network noise. The probe is a [FakeProbe] that
/// returns synchronously — any time measured here is *coordinator overhead*.
///
/// This is the cleanest before/after signal for the refactor: pre-refactor
/// includes the inline `_observer.onCheckCompleted` virtual call;
/// post-refactor will include the `scheduleMicrotask(...)` + event-bus
/// dispatch. The delta tells us the cost of the indirection.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/fake_probe.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

final class _CheckOnceBenchmark extends AsyncBenchmarkBase {
  _CheckOnceBenchmark(this._checker) : super('check_once_overhead');

  final InternetConnection _checker;

  @override
  Future<void> run() => _checker.checkOnce();
}

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final checker = InternetConnection(
    targets: [ProbeTarget(uri: Uri.parse('http://fake/'))],
    probe: FakeProbe.alwaysSuccess(responseTime: Duration.zero),
  );

  forceGc();
  final microseconds = await _CheckOnceBenchmark(checker).measure();

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'check_once_overhead',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );
  writer.writeRecord(
    iteration: args.iteration,
    samples: {
      'microseconds_per_check': [microseconds],
    },
    summary: {'median_microseconds': microseconds},
  );
  await writer.close();
  await checker.dispose();
}
