import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Writes 1 JSON record per iteration, appended to a per-run output file. Schema lives in
/// [benchmark/README.md](../README.md#result-json-schema).
///
/// One per scenario invocation: [open], a [writeRecord] per iteration, then [close].
final class ResultWriter {
  final String scenario;
  final String sdkVersion;
  final String packageVersion;
  final String gitSha;
  final IOSink _sink;
  var _firstRecord = true;

  new _({
    required this.scenario,
    required this.sdkVersion,
    required this.packageVersion,
    required this.gitSha,
    required this._sink,
  });

  /// Opens [outputPath] for writing and emits the JSON-array prefix `[`.
  /// Subsequent [writeRecord] calls add comma-separated records.
  /// [close] writes the closing `]` and flushes.
  static Future<ResultWriter> open({
    required String outputPath,
    required String scenario,
    required String sdkVersion,
    required String packageVersion,
    required String gitSha,
  }) async {
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    // The sink is intentionally held for the writer's lifetime and closed by [close]. The lint can't
    // trace ownership across the factory boundary.
    // ignore: close_sinks
    final sink = file.openWrite()..write('[\n');

    return ResultWriter._(
      scenario: scenario,
      sdkVersion: sdkVersion,
      packageVersion: packageVersion,
      gitSha: gitSha,
      sink: sink,
    );
  }

  /// Appends one record. [samples] is the per-metric arrays of raw measurements. [summary] is per-metric
  /// aggregates the scenario chose to pre-compute (the Python analyzer can recompute from samples).
  void writeRecord({
    required int iteration,
    required Map<String, List<num>> samples,
    required Map<String, num> summary,
  }) {
    final record = <String, Object?>{
      'scenario': scenario,
      'iteration': iteration,
      'sdk_version': sdkVersion,
      'package_version': packageVersion,
      'git_sha': gitSha,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'samples': samples,
      'summary': summary,
    };

    if (!_firstRecord) _sink.write(',\n');
    _sink.write(const JsonEncoder.withIndent('  ').convert(record));
    _firstRecord = false;
  }

  Future<void> close() async {
    _sink.write('\n]\n');

    await _sink.flush();
    await _sink.close();
  }
}

/// Nudges a young-gen GC by allocating a pile of garbage and dropping it. The VM is free to ignore
/// you, but it's the usual "clean slate before measuring" move. Call it just before a window opens.
void forceGc() {
  // Allocate ~8 MB of unreachable garbage to provoke young-gen collection.
  // Drop the reference immediately; the VM should reclaim before the next synchronous chunk.
  // ignore: unused_local_variable
  final pressure = List<List<int>>.generate(64, (_) => List<int>.filled(16384, 0));
}
