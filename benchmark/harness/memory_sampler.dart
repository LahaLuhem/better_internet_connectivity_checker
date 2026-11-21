import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';

/// Samples `ProcessInfo.currentRss` across one measured window. Coarser than heap size, but it's
/// the right signal for spotting a leak.
///
/// Every reading here is relative to the window's own first sample, because `currentRss` is
/// process-wide and iterations share a process.
final class MemorySampler() {
  /// Sampling is a cheap syscall. The 1 second this replaced drew a "peak" out of 3 or 4 samples.
  static const _interval = Duration(milliseconds: 250);

  final _samples = <int>[];
  Timer? _timer;

  /// Every RSS sample so far, in bytes, oldest first. The first one is this window's baseline.
  List<int> get samples => List.unmodifiableOf(_samples);

  /// The most this window added on top of its baseline. Zero is normal, it means the process
  /// reused pages it already held.
  int get peakRssDelta => _samples.isEmpty ? 0 : _samples.max - _samples.first;

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

  void _take() => _samples.add(ProcessInfo.currentRss);
}
