import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// A [CheckSchedule] backed by a closure. Keeps every [ScheduleContext] it's handed, which is the
/// only way a test sees the failure streak, since that's private state with no getter.
final class StubSchedule(final Duration Function(ScheduleContext scheduleContext) _respond)
    implements CheckSchedule {
  /// Every context passed to [nextDelay], in order.
  final List<ScheduleContext> receivedContexts = [];

  /// Creates a [StubSchedule].
  this;

  /// The failure streaks seen so far, 1 per [nextDelay] call.
  List<int> get seenFailureStreaks =>
      receivedContexts.map((context) => context.consecutiveFailures).toList(growable: false);

  @override
  Duration nextDelay(ScheduleContext scheduleContext) {
    receivedContexts.add(scheduleContext);

    return _respond(scheduleContext);
  }
}
