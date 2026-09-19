/// Micro-benchmark: one observer-method dispatch.
///
/// Just the virtual call to [ConnectivityObserver.onStatusChangeEmitted], with no [InternetConnection]
/// in the way. The floor for what invoking a callback costs, to compare the event-stream path against.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

final class _ObserverDispatch extends BenchmarkBase {
  final _NoopCountingObserver _observer;
  final InternetStatus _previous;
  final InternetStatus _next;

  new(this._observer, this._previous, this._next) : super('observer_dispatch');

  @override
  void run() => _observer.onStatusChangeEmitted(_previous, _next);
}

/// Counts calls and does nothing else, the way a well-behaved consumer looks in the steady state.
final class _NoopCountingObserver extends ConnectivityObserver {
  new();

  var count = 0;

  @override
  void onStatusChangeEmitted(InternetStatus? previous, InternetStatus next) => count++;
}

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  const previous = Reachable(responseTime: Duration(milliseconds: 10), quality: .good);
  const next = Reachable(responseTime: Duration(milliseconds: 600), quality: .slow);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'observer_dispatch',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  for (var i = 0; i < args.iterations; i++) {
    final observer = _NoopCountingObserver();

    forceGc();
    final microseconds = _ObserverDispatch(observer, previous, next).measure();

    writer.writeRecord(
      iteration: i,
      samples: {
        'microseconds_per_dispatch': [microseconds],
      },
      summary: {'median_microseconds': microseconds, 'total_dispatches': observer.count.toDouble()},
    );
  }

  await writer.close();
}
