import 'dart:io';

/// Parsed CLI arguments for a benchmark scenario or micro entrypoint.
///
/// All benchmark entrypoints accept a small standard set of flags so the
/// Python orchestrator can drive them uniformly:
///
/// * `--iterations N` — required. How many iterations the scenario should
///   run in this single subprocess invocation. The scenario loops 0..N-1
///   internally and emits one record per iteration. Batching iterations in
///   a single process is the dominant optimisation in the suite — process
///   startup and AOT-loading are amortised over N runs instead of paid N
///   times.
/// * `--output P` — required. Path to write the JSON result file to.
/// * `--git-sha SHA` — required. Captured by the orchestrator via
///   `git rev-parse HEAD`. Recorded in every result record for traceability.
/// * `--package-version V` — required. Captured by the orchestrator from
///   `pubspec.yaml`. Recorded in every result record.
/// * `--duration-seconds N` — optional. Default 10. Long-running scenarios
///   honour this; micro-benchmarks ignore it.
///
/// Hand-parsed (no `package:args` dep) — the surface is small enough that
/// the dep would be overkill, and one less transitive constraint.
final class ScenarioArgs {
  final int iterations;
  final String outputPath;
  final String gitSha;
  final String packageVersion;
  final int durationSeconds;

  const ScenarioArgs._({
    required this.iterations,
    required this.outputPath,
    required this.gitSha,
    required this.packageVersion,
    required this.durationSeconds,
  });

  /// The Dart SDK version reported by `Platform.version`. Recorded in result
  /// records — different SDK = baseline must be re-captured.
  static String get sdkVersion => Platform.version.split(' ').first;

  /// Parses the standard scenario CLI flags from [argv]. Exits the process
  /// with a non-zero code on parse failure — benchmarks are non-interactive,
  /// no point throwing an exception nobody will catch.
  factory ScenarioArgs.parse(List<String> argv) {
    final flags = <String, String>{};
    for (var i = 0; i < argv.length; i++) {
      final arg = argv[i];
      if (!arg.startsWith('--')) {
        _die('unexpected positional arg: $arg');
      }
      if (i + 1 >= argv.length) {
        _die('flag $arg missing value');
      }
      flags[arg.replaceFirst('--', '')] = argv[++i];
    }

    final iterations = _requiredInt(flags, 'iterations');
    if (iterations <= 0) {
      _die('--iterations must be >= 1, got: $iterations');
    }
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
    if (value == null || value.isEmpty) {
      _die('missing required flag: --$name');
    }

    return value;
  }

  static int _requiredInt(Map<String, String> flags, String name) {
    final raw = _required(flags, name);
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      _die('flag --$name expects an int, got: $raw');
    }

    return parsed;
  }

  static Never _die(String message) {
    stderr.writeln('scenario_args: $message');
    exit(64); // EX_USAGE
  }
}
