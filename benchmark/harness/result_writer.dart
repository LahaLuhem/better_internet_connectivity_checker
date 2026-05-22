import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Writes scenario-result JSON conforming to the schema documented in
/// [`~/Desktop/bicc-benchmark-plan-2026-05-21.md`](file:///Users/mehul/Desktop/bicc-benchmark-plan-2026-05-21.md)
/// §5 — one record per iteration, appended to a per-run output file.
///
/// One [ResultWriter] per scenario invocation. Construct, call [open],
/// emit one [writeRecord] per iteration, then [close].
final class ResultWriter {
  final String scenario;
  final String sdkVersion;
  final String packageVersion;
  final String gitSha;
  final IOSink _sink;
  var _firstRecord = true;

  ResultWriter._({
    required this.scenario,
    required this.sdkVersion,
    required this.packageVersion,
    required this.gitSha,
    required IOSink sink,
  }) : _sink = sink;

  /// Opens [outputPath] for writing and emits the JSON-array prefix `[`.
  /// Subsequent [writeRecord] calls add comma-separated records;
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
    // The sink is intentionally held for the writer's lifetime and closed by
    // [close]; the lint can't trace ownership across the factory boundary.
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

  /// Appends one record. [samples] is the per-metric arrays of raw
  /// measurements; [summary] is per-metric aggregates the scenario chose
  /// to pre-compute (the Python analyzer can recompute from samples).
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

/// Forces a young-generation GC by allocating then dropping a large amount
/// of pressure. Imperfect — the Dart VM is free to defer — but the
/// canonical "I want a clean slate before measuring" pattern.
///
/// Call this immediately before opening a measurement window. Idempotent.
void forceGc() {
  // Allocate ~8 MB of unreachable garbage to provoke young-gen collection.
  // Drop the reference immediately; the VM should reclaim before the next
  // synchronous chunk.
  // ignore: unused_local_variable
  final pressure = List<List<int>>.generate(64, (_) => List<int>.filled(16384, 0));
}
