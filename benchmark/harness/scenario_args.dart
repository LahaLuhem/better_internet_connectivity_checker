import 'dart:io';

/// Parsed CLI arguments for a benchmark scenario or micro entrypoint.
///
/// Every entrypoint accepts the same standard flags so the Python orchestrator drives them
/// uniformly:
///
/// * `--iterations N` — required. Iterations to run in this one subprocess (loops 0..N-1, one record each).
///   Batching in a single process amortises startup + AOT-load over N runs — the suite's dominant optimisation.
/// * `--output P` — required. Where to write the JSON result file.
/// * `--git-sha SHA` — required. Captured via `git rev-parse HEAD`; recorded per record for traceability.
/// * `--package-version V` — required. Captured from `pubspec.yaml`; recorded per record.
/// * `--duration-seconds N` — optional, default 10. Scenarios honour it; micros ignore it.
///
/// Hand-parsed — the surface is too small to justify a `package:args` dependency.
final class ScenarioArgs {
  final int iterations;
  final String outputPath;
  final String gitSha;
  final String packageVersion;
  final int durationSeconds;

  const new _({
    required this.iterations,
    required this.outputPath,
    required this.gitSha,
    required this.packageVersion,
    required this.durationSeconds,
  });

  /// The Dart SDK version reported by `Platform.version`. Recorded in result records — different SDK
  /// = baseline must be re-captured.
  static String get sdkVersion => Platform.version.split(' ').first;

  /// Parses the standard scenario CLI flags from [argv]. Exits the process with a non-zero code on
  /// parse failure — benchmarks are non-interactive, no point throwing an exception nobody will catch.
  factory parse(List<String> argv) {
    final flags = <String, String>{};
    for (var i = 0; i < argv.length; i++) {
      final arg = argv[i];
      if (!arg.startsWith('--')) _die('unexpected positional arg: $arg');
      if (i + 1 >= argv.length) _die('flag $arg missing value');
      flags[arg.replaceFirst('--', '')] = argv[++i];
    }

    final iterations = _requiredInt(flags, 'iterations');
    if (iterations <= 0) _die('--iterations must be >= 1, got: $iterations');

    final outputPath = _required(flags, 'output');
    final gitSha = _required(flags, 'git-sha');
    final packageVersion = _required(flags, 'package-version');
    final durationSeconds = int.tryParse(flags['duration-seconds'] ?? '10') ?? 10;

    return ScenarioArgs._(
      iterations: iterations,
      outputPath: outputPath,
      gitSha: gitSha,
      packageVersion: packageVersion,
      durationSeconds: durationSeconds,
    );
  }

  static String _required(Map<String, String> flags, String name) {
    final value = flags[name];
    if (value == null || value.isEmpty) _die('missing required flag: --$name');

    return value;
  }

  static int _requiredInt(Map<String, String> flags, String name) {
    final raw = _required(flags, name);
    final parsed = int.tryParse(raw);
    if (parsed == null) _die('flag --$name expects an int, got: $raw');

    return parsed;
  }

  static Never _die(String message) {
    stderr.writeln('scenario_args: $message');
    exit(64); // EX_USAGE
  }
}
