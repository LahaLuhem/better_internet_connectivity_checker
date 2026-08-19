import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// A [CheckSchedule] that delegates to a caller-supplied closure.
///
/// Lives under `test/support/` so the production code stays free of test scaffolding. Records every
/// [ScheduleContext] it was handed, which is how connection tests observe the failure streak: the
/// streak is private state on `InternetConnection` with no getter.
final class StubSchedule(final Duration Function(ScheduleContext scheduleContext) _respond)
    implements CheckSchedule {
  /// Every context passed to [nextDelay], in order.
  final List<ScheduleContext> receivedContexts = [];

  /// Creates a [StubSchedule].
  this;

  /// The failure streaks seen so far, one per [nextDelay] call.
  List<int> get seenFailureStreaks =>
      receivedContexts.map((context) => context.consecutiveFailures).toList(growable: false);

  @override
  Duration nextDelay(ScheduleContext scheduleContext) {
    receivedContexts.add(scheduleContext);

    return _respond(scheduleContext);
  }
}
