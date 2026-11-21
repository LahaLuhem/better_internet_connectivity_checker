import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/foundation.dart';
import 'package:listenable_collections/listenable_collections.dart';
import 'package:pmvvm/pmvvm.dart';

import 'data/constants/const_schedule_comparison.dart';

/// One rung of a ladder: the delay a schedule asked for, and the streak behind it.
typedef ScheduledRung = ({Duration delay, int consecutiveFailures});

final class ScheduleComparisonViewModel() extends ViewModel {
  InternetConnection? _fixedConnection;
  InternetConnection? _backoffConnection;
  final _subscriptions = <StreamSubscription<void>>[];

  final _fixedRungsNotifier = ListNotifier<ScheduledRung>();
  final _backoffRungsNotifier = ListNotifier<ScheduledRung>();
  final _shouldProbeReachableTargetNotifier = ValueNotifier(false);
  final _shouldJitterNotifier = ValueNotifier(false);

  @override
  void init() => _buildConnections();

  ValueListenable<List<ScheduledRung>> get fixedRungsListenable => _fixedRungsNotifier;

  ValueListenable<List<ScheduledRung>> get backoffRungsListenable => _backoffRungsNotifier;

  ValueListenable<bool> get shouldProbeReachableTargetListenable =>
      _shouldProbeReachableTargetNotifier;

  ValueListenable<bool> get shouldJitterListenable => _shouldJitterNotifier;

  void onTargetReachabilityToggled({required bool value}) {
    _shouldProbeReachableTargetNotifier.value = value;
    _buildConnections();
  }

  void onJitterToggled({required bool value}) {
    _shouldJitterNotifier.value = value;
    _buildConnections();
  }

  void _buildConnections() {
    // Fire-and-forget teardown: the notifiers below are rebuilt immediately, and a
    // late event from a disposed connection cannot reach a cancelled subscription.
    unawaited(_teardown());

    _fixedRungsNotifier.clear();
    _backoffRungsNotifier.clear();

    final targets = _shouldProbeReachableTargetNotifier.value
        ? ConstScheduleComparison.reachableTargets
        : ConstScheduleComparison.unreachableTargets;

    final fixedConnection = InternetConnection(
      targets: targets,
      checkInterval: ConstScheduleComparison.baseInterval,
    );
    final backoffConnection = InternetConnection(
      targets: targets,
      checkInterval: ConstScheduleComparison.baseInterval,
      // Off by default so the ladder reads as clean doublings; the switch shows the spread a
      // caller actually gets, since the package jitters by default.
      schedule: ExponentialBackoffSchedule(
        maxDelay: ConstScheduleComparison.maxBackoffDelay,
        randomizationFactor: !_shouldJitterNotifier.value
            ? 0
            : ConstScheduleComparison.demoRandomizationFactor,
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
  }) => connection.events.listen((event) => recordRung(event, isBackoff: isBackoff));

  /// Split out so a test can drive it without standing up a real connection.
  @visibleForTesting
  void recordRung(ConnectivityEvent event, {required bool isBackoff}) {
    if (event case NextCheckScheduledEvent(:final delay, :final scheduleContext)) {
      final rungsNotifier = isBackoff ? _backoffRungsNotifier : _fixedRungsNotifier;
      // Keeps the first rungs, which are the interesting ones: past the cap every
      // later delay is identical. Bailing out also spares a tick per capped check.
      if (rungsNotifier.length >= ConstScheduleComparison.ladderLength) return;

      rungsNotifier.add((delay: delay, consecutiveFailures: scheduleContext.consecutiveFailures));
    }
  }

  Future<void> _teardown() {
    final pendingFutures = [
      ..._subscriptions.map((subscription) => subscription.cancel()),
      ?_fixedConnection?.dispose(),
      ?_backoffConnection?.dispose(),
    ];
    _subscriptions.clear();
    _fixedConnection = null;
    _backoffConnection = null;

    return pendingFutures.wait;
  }

  @override
  void dispose() {
    unawaited(_teardown());
    _fixedRungsNotifier.dispose();
    _backoffRungsNotifier.dispose();
    _shouldProbeReachableTargetNotifier.dispose();
    _shouldJitterNotifier.dispose();

    super.dispose();
  }
}
