import 'dart:async';
import 'dart:io';

/// Periodically samples `ProcessInfo.currentRss` to track resident set size
/// over a benchmark run. RSS is the OS-reported physical memory the process
/// holds — coarser than per-instance heap, but the right signal for leak
/// detection over long runs.
///
/// Usage:
///
/// ```dart
/// final sampler = MemorySampler(interval: Duration(seconds: 1))..start();
/// // ... run scenario ...
/// sampler.stop();
/// final samples = sampler.samples; // List<int> of RSS bytes
/// ```
///
/// Defaults to 1-second sampling. Faster sampling has minimal cost
/// (`ProcessInfo.currentRss` is a `getrusage` syscall on Unix), but
/// adds noise; slower sampling misses short-lived spikes.
final class MemorySampler {
  final Duration _interval;
  final _samples = <int>[];
  final _timestamps = <DateTime>[];
  Timer? _timer;

  MemorySampler({Duration interval = const Duration(seconds: 1)}) : _interval = interval;

  /// Snapshot of all RSS samples (bytes) collected so far, in chronological
  /// order. Returned as an unmodifiable view.
  List<int> get samples => List.unmodifiable(_samples);

  /// Timestamps matching [samples] one-to-one.
  List<DateTime> get timestamps => List.unmodifiable(_timestamps);

  /// Peak RSS observed across all samples, in bytes. Returns 0 if no samples
  /// have been collected.
  int get peakRss => _samples.isEmpty ? 0 : _samples.reduce((a, b) => a > b ? a : b);

  /// Minimum RSS observed. Useful as the "idle" baseline for a quiet scenario.
  int get minRss => _samples.isEmpty ? 0 : _samples.reduce((a, b) => a < b ? a : b);

  /// RSS delta between the first and last sample. Positive = growth (potential
  /// leak); near-zero = steady state.
  int get rssDelta => _samples.length < 2 ? 0 : _samples.last - _samples.first;

  /// Starts periodic sampling. Throws if already started — call [stop] first
  /// to reuse the same sampler instance.
  ///
  /// Samples immediately on start so there's at least one data point even
  /// for very short scenarios.
  void start() {
    if (_timer != null) throw StateError('MemorySampler already started');
    _take();
    _timer = Timer.periodic(_interval, (_) => _take());
  }

  /// Stops sampling. Idempotent — safe to call multiple times.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Forces an immediate sample outside the periodic schedule. Useful for
  /// capturing RSS at known interesting moments (e.g. right after
  /// `InternetConnection` construction).
  void sampleNow() => _take();

  void _take() {
    _samples.add(ProcessInfo.currentRss);
    _timestamps.add(DateTime.now().toUtc());
  }
}
