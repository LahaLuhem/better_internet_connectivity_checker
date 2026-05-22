/// Micro-benchmark: cost of one observer-method dispatch.
///
/// Measures the virtual-call cost of [ConnectivityObserver.onStatusChangeEmitted]
/// in isolation — bypasses [InternetConnection] entirely. The point is to put
/// a number on "what does one fan-out site cost today" so the post-refactor
/// `_events.add(StatusEmittedEvent(...))` path has a direct comparison.
///
/// Pre-refactor expected cost: ~one virtual dispatch + no allocation.
/// Post-refactor expected cost: ~one allocation (event object) + microtask
/// schedule + broadcast `add`. This bench captures the "before".
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

/// Minimal subclass — counts calls but does no work. Mirrors what a
/// PrintingConnectivityObserver-style consumer looks like in the steady
/// state (no expensive side effect on the hot path).
final class _NoopCountingObserver extends ConnectivityObserver {
  _NoopCountingObserver();

  var count = 0;

  @override
  void onStatusChangeEmitted(InternetStatus? previous, InternetStatus next) => count++;
}

final class _DispatchBenchmark extends BenchmarkBase {
  _DispatchBenchmark(this._observer, this._previous, this._next) : super('observer_dispatch');

  final _NoopCountingObserver _observer;
  final InternetStatus _previous;
  final InternetStatus _next;

  @override
  void run() => _observer.onStatusChangeEmitted(_previous, _next);
}

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final observer = _NoopCountingObserver();
  const previous = Reachable(
    responseTime: Duration(milliseconds: 10),
    quality: ConnectionQuality.good,
  );
  const next = Reachable(
    responseTime: Duration(milliseconds: 600),
    quality: ConnectionQuality.slow,
  );

  forceGc();
  final microseconds = _DispatchBenchmark(observer, previous, next).measure();

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'observer_dispatch',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );
  writer.writeRecord(
    iteration: args.iteration,
    samples: {
      'microseconds_per_dispatch': [microseconds],
    },
    summary: {'median_microseconds': microseconds, 'total_dispatches': observer.count.toDouble()},
  );
  await writer.close();
}
