/// Quality classification of a reachable internet connection.
///
/// Carried on a successful status to signal whether the response time fell within the configured
/// slow threshold. With no threshold configured, every reachable status reports [ConnectionQuality.good].
enum ConnectionQuality {
  /// Response time was at or under the slow threshold, or no threshold was configured.
  good,

  /// Response time exceeded the configured slow threshold.
  slow,
}
