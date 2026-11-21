import 'package:better_internet_conn_check_example/features/schedule_comparison/data/constants/const_schedule_comparison.dart';
import 'package:better_internet_conn_check_example/features/schedule_comparison/schedule_comparison_view_model.dart';
import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter_test/flutter_test.dart';

NextCheckScheduledEvent _scheduled({required Duration delay, required int consecutiveFailures}) =>
    NextCheckScheduledEvent(
      delay: delay,
      scheduleContext: ScheduleContext(
        baseInterval: ConstScheduleComparison.baseInterval,
        consecutiveFailures: consecutiveFailures,
        lastStatus: const Unreachable(failedProbes: []),
      ),
    );

void main() {
  late ScheduleComparisonViewModel viewModel;

  setUp(() {
    // No init(), which would stand up 2 real connections against the network.
    viewModel = ScheduleComparisonViewModel();
    addTearDown(viewModel.dispose);
  });

  test('a scheduled check lands on the ladder it came from, carrying delay and streak', () {
    viewModel.recordRung(
      _scheduled(delay: const Duration(seconds: 8), consecutiveFailures: 2),
      isBackoff: true,
    );

    expect(viewModel.fixedRungsListenable.value, isEmpty);
    expect(viewModel.backoffRungsListenable.value, [
      (delay: const Duration(seconds: 8), consecutiveFailures: 2),
    ]);
  });

  test('each ladder fills independently', () {
    viewModel
      ..recordRung(
        _scheduled(delay: ConstScheduleComparison.baseInterval, consecutiveFailures: 1),
        isBackoff: false,
      )
      ..recordRung(
        _scheduled(delay: const Duration(seconds: 4), consecutiveFailures: 2),
        isBackoff: true,
      );

    expect(viewModel.fixedRungsListenable.value, hasLength(1));
    expect(viewModel.backoffRungsListenable.value, hasLength(1));
  });

  test('a ladder stops growing once it is full', () {
    for (var rung = 0; rung < ConstScheduleComparison.ladderLength + 3; rung++) {
      viewModel.recordRung(
        _scheduled(
          delay: Duration(seconds: rung),
          consecutiveFailures: rung,
        ),
        isBackoff: false,
      );
    }

    expect(viewModel.fixedRungsListenable.value, hasLength(ConstScheduleComparison.ladderLength));
    // The ones kept are the first, where the delays still differ.
    expect(viewModel.fixedRungsListenable.value.first.delay, Duration.zero);
  });

  test('an event that is not a scheduled check records nothing', () {
    viewModel
      ..recordRung(const DisposedEvent(), isBackoff: false)
      ..recordRung(const ExternalTriggerFiredEvent(), isBackoff: true);

    expect(viewModel.fixedRungsListenable.value, isEmpty);
    expect(viewModel.backoffRungsListenable.value, isEmpty);
  });

  test('appending notifies the ladder listeners', () {
    var notifications = 0;
    viewModel.fixedRungsListenable.addListener(() => notifications++);

    viewModel.recordRung(
      _scheduled(delay: ConstScheduleComparison.baseInterval, consecutiveFailures: 1),
      isBackoff: false,
    );

    expect(notifications, 1);
  });
}
