abstract final class ConstFormatters {
  static String humanReadableDuration(Duration duration) {
    if (duration.inMilliseconds < Duration.millisecondsPerSecond) {
      return '${duration.inMilliseconds} ms';
    }
    final seconds = duration.inMilliseconds / Duration.millisecondsPerSecond;

    return '${seconds.toStringAsFixed(2)} s';
  }

  static String describeProbeError(Object? error) {
    if (error == null) return 'predicate rejected response';

    return error.runtimeType.toString();
  }
}
