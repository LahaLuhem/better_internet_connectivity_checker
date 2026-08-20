import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

abstract final class ConstScheduleComparison {
  /// Base interval both checkers run at. Short so the backoff ladder is visible
  /// within a few seconds of opening the demo.
  static const baseInterval = Duration(seconds: 2);

  /// Ceiling for the backoff checker. Low enough to reach on screen.
  static const maxBackoffDelay = Duration(seconds: 32);

  /// How many planned delays each ladder shows, counted from the first check.
  /// Bounded so a demo left running does not grow a list forever; six rungs is
  /// enough to reach [maxBackoffDelay] from [baseInterval].
  static const ladderLength = 6;

  /// Spread applied when the jitter switch is on. Matches the package default, so the
  /// rows show what a caller gets without configuring anything.
  static const demoRandomizationFactor = 0.25;

  /// Fails fast on DNS, which drives the failure streak without waiting out a
  /// per-target timeout.
  static final unreachableTargets = [
    ProbeTarget(uri: Uri.https('this-domain-definitely-does-not-resolve.invalid')),
  ];

  /// Used by the recovery toggle, to show both ladders snapping back.
  static final reachableTargets = [ProbeTarget(uri: Uri.https('one.one.one.one'))];
}
