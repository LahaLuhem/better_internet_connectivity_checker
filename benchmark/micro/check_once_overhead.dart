/// Micro-benchmark: cost of one `InternetConnection.checkOnce()` against an instant fake probe.
///
/// Isolates the coordinator's per-check cost (probe call → policy aggregation → result construction)
/// from network noise: the [FakeProbe] returns synchronously, so any time measured here is *coordinator
/// overhead*, the baseline for judging any dispatch-path change.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/fake_probe.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

final class _CheckOnceOverhead extends AsyncBenchmarkBase {
  final InternetConnection _checker;

  _CheckOnceOverhead(this._checker) : super('check_once_overhead');

  @override
  Future<void> run() => _checker.checkOnce();
}

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'check_once_overhead',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  for (var i = 0; i < args.iterations; i++) {
    final checker = InternetConnection(
      targets: [ProbeTarget(uri: Uri.parse('http://fake/'))],
      probe: FakeProbe.alwaysSuccess(responseTime: .zero),
    );

    forceGc();
    final microseconds = await _CheckOnceOverhead(checker).measure();

    writer.writeRecord(
      iteration: i,
      samples: {
        'microseconds_per_check': [microseconds],
      },
      summary: {'median_microseconds': microseconds},
    );

    await checker.dispose();
    forceGc();
  }

  await writer.close();
}
