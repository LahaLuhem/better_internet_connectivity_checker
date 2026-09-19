import 'dart:io';

/// The CLI flags every benchmark entrypoint takes, so the Python orchestrator drives them all the
/// same way. `--iterations`, `--output`, `--git-sha` and `--package-version` are required.
/// `--duration-seconds` defaults to 10, and micros ignore it.
///
/// Batching iterations into one subprocess spreads startup and AOT-load over N, which is the single
/// biggest win in the suite. Hand-parsed, since this is far too small to want `package:args`.
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

  /// From `Platform.version`. A different SDK means the baseline has to be captured again.
  static String get sdkVersion => Platform.version.split(' ').first;

  /// Parses [argv], exiting non-zero on a bad flag rather than throwing. Nothing here is interactive
  /// enough for anyone to catch it.
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
