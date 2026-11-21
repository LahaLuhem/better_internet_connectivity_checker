abstract final class ConstFormatters._() {
  static String humanReadableDuration(Duration duration) {
    if (duration.inMilliseconds < Duration.millisecondsPerSecond) {
      return '${duration.inMilliseconds} ms';
    }
    final fractionalSeconds = duration.inMilliseconds / Duration.millisecondsPerSecond;

    return '${fractionalSeconds.toStringAsFixed(2)} s';
  }

  static String describeProbeError(Object? error) {
    if (error == null) return 'predicate rejected response';

    return error.runtimeType.toString();
  }
}
