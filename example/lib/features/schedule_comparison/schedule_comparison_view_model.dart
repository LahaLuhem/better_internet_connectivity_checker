import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/foundation.dart';
import 'package:pmvvm/pmvvm.dart';

import 'data/constants/const_schedule_comparison.dart';

/// One rung of a ladder: the delay a schedule asked for, and the streak behind it.
typedef ScheduledRung = ({Duration delay, int consecutiveFailures});

/// Both ladders, always written together as one tick.
typedef LadderState = ({List<ScheduledRung> fixed, List<ScheduledRung> backoff});

final class ScheduleComparisonViewModel extends ViewModel {
  InternetConnection? _fixedConnection;
  InternetConnection? _backoffConnection;
  final _subscriptions = <StreamSubscription<void>>[];

  final _ladderStateNotifier = ValueNotifier<LadderState>((fixed: [], backoff: []));
  final _isTargetReachableNotifier = ValueNotifier(false);

  @override
  void init() => _buildConnections();

  ValueListenable<LadderState> get ladderStateListenable => _ladderStateNotifier;

  ValueListenable<bool> get isTargetReachableListenable => _isTargetReachableNotifier;

  void onTargetReachabilityToggled({required bool value}) {
    _isTargetReachableNotifier.value = value;
    _buildConnections();
  }

  void _buildConnections() {
    // Fire-and-forget teardown: the notifiers below are rebuilt immediately, and a
    // late event from a disposed connection cannot reach a cancelled subscription.
    unawaited(_teardown());

    _ladderStateNotifier.value = (fixed: [], backoff: []);

    final targets = _isTargetReachableNotifier.value
        ? ConstScheduleComparison.reachableTargets
        : ConstScheduleComparison.unreachableTargets;

    final fixedConnection = InternetConnection(
      targets: targets,
      checkInterval: ConstScheduleComparison.baseInterval,
    );
    final backoffConnection = InternetConnection(
      targets: targets,
      checkInterval: ConstScheduleComparison.baseInterval,
      // Jitter off so the ladder reads as clean doublings; it is a separate lesson.
      schedule: const ExponentialBackoffSchedule(
        maxDelay: ConstScheduleComparison.maxBackoffDelay,
        randomizationFactor: 0,
      ),
    );

    _fixedConnection = fixedConnection;
    _backoffConnection = backoffConnection;

    _subscriptions.addAll([
      _recordLadder(fixedConnection, isBackoff: false),
      _recordLadder(backoffConnection, isBackoff: true),
      // The periodic loop only runs while onStatusChange has a listener.
      fixedConnection.onStatusChange.listen(noopWithVal),
      backoffConnection.onStatusChange.listen(noopWithVal),
    ]);
  }

  StreamSubscription<ConnectivityEvent> _recordLadder(
    InternetConnection connection, {
    required bool isBackoff,
  }) => connection.events.listen((event) {
    if (event case NextCheckScheduledEvent(:final delay, :final scheduleContext)) {
      final current = _ladderStateNotifier.value;
      final existing = isBackoff ? current.backoff : current.fixed;
      // Keeps the first rungs, which are the interesting ones: past the cap every
      // later delay is identical. Bailing out also spares a tick per capped check.
      if (existing.length >= ConstScheduleComparison.ladderLength) return;

      final updated = [
        ...existing,
        (delay: delay, consecutiveFailures: scheduleContext.consecutiveFailures),
      ];

      _ladderStateNotifier.value = isBackoff
          ? (fixed: current.fixed, backoff: updated)
          : (fixed: updated, backoff: current.backoff);
    }
  });

  Future<void> _teardown() async {
    final pending = [
      ..._subscriptions.map((subscription) => subscription.cancel()),
      ?_fixedConnection?.dispose(),
      ?_backoffConnection?.dispose(),
    ];
    _subscriptions.clear();
    _fixedConnection = null;
    _backoffConnection = null;

    await pending.wait;
  }

  @override
  void dispose() {
    unawaited(_teardown());
    _ladderStateNotifier.dispose();
    _isTargetReachableNotifier.dispose();
    super.dispose();
  }
}
