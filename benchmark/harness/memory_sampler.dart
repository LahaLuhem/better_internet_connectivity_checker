import 'dart:async';
import 'dart:io';

/// Samples `ProcessInfo.currentRss` on a timer, to watch resident memory across a run. Coarser than
/// heap size, but it's the right signal for spotting a leak.
///
/// 1 second by default. Faster is cheap, `currentRss` is just a `getrusage` syscall, but noisier.
/// Slower misses short spikes.
final class MemorySampler {
  final Duration _interval;
  final _samples = <int>[];
  final _timestamps = <DateTime>[];
  Timer? _timer;

  new({this._interval = const Duration(seconds: 1)});

  /// Every RSS sample so far, in bytes, oldest first.
  List<int> get samples => List.unmodifiable(_samples);

  /// Timestamps matching [samples] one-to-one.
  List<DateTime> get timestamps => List.unmodifiable(_timestamps);

  /// Highest RSS seen, in bytes. Zero when nothing has been sampled.
  int get peakRss => _samples.isEmpty ? 0 : _samples.reduce((a, b) => a > b ? a : b);

  /// Lowest RSS seen, which makes a decent idle baseline.
  int get minRss => _samples.isEmpty ? 0 : _samples.reduce((a, b) => a < b ? a : b);

  /// Last sample minus the first. Climbing means growth, which means a possible leak.
  int get rssDelta => _samples.length < 2 ? 0 : _samples.last - _samples.first;

  /// Starts sampling, taking one straight away so even a very short run has a data point. Throws if
  /// it's already running, so [stop] first to reuse one.
  void start() {
    if (_timer != null) throw StateError('MemorySampler already started');
    _take();
    _timer = Timer.periodic(_interval, (_) => _take());
  }

  /// Stops sampling. Safe to call twice.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Takes a sample right now, off-schedule, for a known interesting moment.
  void sampleNow() => _take();

  void _take() {
    _samples.add(ProcessInfo.currentRss);
    _timestamps.add(DateTime.now().toUtc());
  }
}
