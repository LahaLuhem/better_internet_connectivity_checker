/// Micro-benchmark: cost of one observer-method dispatch.
///
/// Measures the virtual-call cost of [ConnectivityObserver.onStatusChangeEmitted] in isolation, bypassing
/// [InternetConnection] — a floor for "what does invoking one callback cost", against which the event-stream
/// path (allocate event + microtask + broadcast `add`) can be compared.
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

/// Minimal subclass — counts calls but does no work. Mirrors what a PrintingConnectivityObserver-style
/// consumer looks like in the steady state (no expensive side effect on the hot path).
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
