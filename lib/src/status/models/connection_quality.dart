/// Whether a reachable connection came back fast enough, judged against the slow threshold.
enum ConnectionQuality {
  /// Came back inside the threshold, or no threshold was set.
  good,

  /// Took longer than the threshold.
  slow,
}
