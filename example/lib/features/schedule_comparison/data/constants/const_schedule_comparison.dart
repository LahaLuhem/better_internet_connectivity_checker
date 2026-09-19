import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

abstract final class ConstScheduleComparison {
  /// Base interval both checkers run at. Short, so the backoff ladder shows up within seconds of
  /// opening the demo.
  static const baseInterval = Duration(seconds: 2);

  /// Ceiling for the backoff checker. Low enough to reach on screen.
  static const maxBackoffDelay = Duration(seconds: 32);

  /// How many planned delays each ladder shows. Capped so a demo left running doesn't grow a list
  /// forever, and 6 rungs is enough to get from [baseInterval] to [maxBackoffDelay].
  static const ladderLength = 6;

  /// Spread applied when the jitter switch is on. Matches the package default, so the rows show what
  /// you get out of the box.
  static const demoRandomizationFactor = 0.25;

  /// Fails fast on DNS, which builds the failure streak without waiting out a per-target timeout.
  static final unreachableTargets = [
    ProbeTarget(uri: Uri.https('this-domain-definitely-does-not-resolve.invalid')),
  ];

  /// Used by the recovery toggle, to show both ladders snapping back.
  static final reachableTargets = [ProbeTarget(uri: Uri.https('one.one.one.one'))];
}
