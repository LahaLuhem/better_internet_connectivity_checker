/// Quality classification of a reachable internet connection.
///
/// Carried inside a successful reachability status to communicate whether the
/// observed response time fell within the configured slow threshold. When no
/// slow threshold is configured, every reachable status reports
/// [ConnectionQuality.good].
enum ConnectionQuality {
  /// Response time was at or under the configured slow threshold, or no
  /// threshold was configured.
  good,

  /// Response time exceeded the configured slow threshold.
  slow,
}
