/// @docImport 'observer/connectivity_observer.dart';
/// @docImport 'schedule/strategies/exponential_backoff_schedule.dart';
library;

import 'dart:async';

import 'data/values.dart';
import 'observer/events/connectivity_event.dart';
import 'policy/reachability_policy.dart';
import 'policy/strategies/any_reachable_policy.dart';
import 'probe/connectivity_probe.dart';
import 'probe/models/probe_result.dart';
import 'probe/models/probe_target.dart';
import 'probe/transports/http_probe.dart';
import 'schedule/check_schedule.dart';
import 'schedule/models/schedule_context.dart';
import 'schedule/strategies/fixed_interval_schedule.dart';
import 'status/internet_status.dart';
import 'status/models/connection_quality.dart';

part 'internal/deadline_probe.dart';
part 'internal/event_sink.dart';
part 'internal/external_trigger_link.dart';
part 'internal/periodic_scheduler.dart';

/// Runs the checks and hands you the results.
///
/// [checkOnce] for a one-off answer, [onStatusChange] for a stream that keeps checking on its own.
/// No singleton here, so build one per use case, and [dispose] it when you're done.
final class InternetConnection({
  /// What to probe on each check. Defaults to 3 endpoints on 3 different operators, so one
  /// provider having a bad day can't fail the lot. Must not be empty.
  List<ProbeTarget>? targets,

  /// Gap between periodic checks, once [onStatusChange] has a listener. Under a non-fixed `schedule`
  /// this is the base each gap grows from rather than the gap itself.
  var Duration _checkInterval = Values.defaultCheckInterval,

  /// How probe results roll up into one verdict. Defaults to [AnyReachablePolicy], any-of-N.
  final ReachabilityPolicy _policy = const AnyReachablePolicy(),

  /// Picks the gap before each next check. Defaults to [FixedIntervalSchedule]. Swap in
  /// [ExponentialBackoffSchedule] to back off while checks keep failing.
  final CheckSchedule _schedule = const FixedIntervalSchedule(),

  /// Response time above which a reachable connection counts as [ConnectionQuality.slow]. Null, the
  /// default, means everything reachable is [ConnectionQuality.good].
  var Duration? _slowThreshold,

  /// How one target gets checked. Defaults to [HttpProbe.head]. Whatever you pass is capped at the
  /// target's [ProbeTarget.timeout], so a probe that retries has to fit every attempt inside that.
  ConnectivityProbe? probe,

  /// Every event on this stream forces an immediate recheck. In Flutter that's usually
  /// `Connectivity().onConnectivityChanged.map(noopWithVal)`.
  Stream<void>? externalRecheckTrigger,
}) {
  final List<ProbeTarget> _targets = targets != null
      ? List.unmodifiable(targets)
      : Values.defaultProbeTargets;
  final ConnectivityProbe _probe = _DeadlineProbe(probe ?? HttpProbe.head());
  final _externalTrigger = externalRecheckTrigger;

  late final _statusController = StreamController<InternetStatus>.broadcast(
    onListen: _handleFirstListener,
    onCancel: _handleLastCancel,
  );
  final _eventSink = _EventSink();
  late final _scheduler = _PeriodicScheduler(onTick: _runScheduledCheck);
  late final _triggerLink = _ExternalTriggerLink(
    trigger: _externalTrigger,
    onTrigger: () {
      _eventSink.emit(const ExternalTriggerFiredEvent());
      _consecutiveFailures = 0;
      _scheduler.start();
    },
    onError: (error, stackTrace) {
      _eventSink.emit(ExternalTriggerErrorEvent(error, stackTrace));
    },
  );
  InternetStatus? _lastStatus;
  var _consecutiveFailures = 0;
  var _disposed = false;

  /// Creates an [InternetConnection].
  this : assert(targets == null || targets.isNotEmpty, 'targets must be non-empty');

  /// The current periodic check interval.
  Duration get checkInterval => _checkInterval;

  /// The current slow cutoff, or null when slow detection is off.
  Duration? get slowThreshold => _slowThreshold;

  /// Last status seen. Null before the first check, and null again once the last [onStatusChange]
  /// listener cancels.
  InternetStatus? get lastStatus => _lastStatus;

  /// Status changes, deduped on kind: the same kind twice running fires once, good to slow fires.
  ///
  /// Checking starts on the first listener and pauses when the last one cancels.
  Stream<InternetStatus> get onStatusChange => _statusController.stream;

  /// Lifecycle events: checks, status emissions, triggers, config changes, dispose.
  ///
  /// Delivered a microtask late, so a slow listener can't stall the caller. It can still block the
  /// isolate though, see [ConnectivityObserver]. [DisposedEvent] always lands, anything queued after
  /// it is dropped.
  Stream<ConnectivityEvent> get events => _eventSink.stream;

  /// Runs one check right now, off to the side: the timer, [onStatusChange] and [lastStatus] are all
  /// left alone.
  ///
  /// Built-in policies probe in parallel, so this takes about as long as the slowest
  /// [ProbeTarget.timeout].
  Future<InternetStatus> checkOnce() =>
      _policy.evaluate(targets: _targets, probe: _probe, slowThreshold: _slowThreshold);

  /// Updates the periodic check interval and resets any running timer.
  set checkInterval(Duration interval) {
    final previous = _checkInterval;
    _checkInterval = interval;
    _eventSink.emit(CheckIntervalChangedEvent(previous: previous, next: interval));
    _scheduler.rescheduleAfter(interval);
  }

  /// Updates the slow cutoff, which takes effect at the next check. Null turns slow detection off.
  ///
  /// Nothing else moves: no timer reset, no check, [lastStatus] survives. That last part is why this
  /// beats rebuilding the whole thing when only the threshold changed.
  set slowThreshold(Duration? threshold) {
    final previous = _slowThreshold;
    _slowThreshold = threshold;
    _eventSink.emit(SlowThresholdChangedEvent(previous: previous, next: threshold));
  }

  /// Tears down the stream, timer and trigger subscription. Don't use the instance afterwards.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _scheduler.dispose();

    await _triggerLink.stop();

    await _statusController.close();
    await _eventSink.dispose();
  }

  void _handleFirstListener() {
    _triggerLink.start();
    _scheduler.start();
  }

  void _handleLastCancel() {
    if (_statusController.hasListener) return;

    _scheduler.stop();
    unawaited(_triggerLink.stop());

    _lastStatus = null;
    _consecutiveFailures = 0;
  }

  /// Runs one scheduled check and returns the delay before the next one.
  Future<Duration> _runScheduledCheck() async {
    if (_disposed || !_statusController.hasListener) return _checkInterval;

    final status = await checkOnce();
    if (_disposed || !_statusController.hasListener) return _checkInterval;

    _eventSink.emit(CheckCompletedEvent(status));

    if (_isDistinctKind(_lastStatus, status)) {
      _eventSink.emit(StatusEmittedEvent(previous: _lastStatus, next: status));
      _statusController.add(status);
    }
    _lastStatus = status;
    _consecutiveFailures = status is Unreachable ? _consecutiveFailures + 1 : 0;

    final scheduleContext = ScheduleContext(
      baseInterval: _checkInterval,
      consecutiveFailures: _consecutiveFailures,
      lastStatus: status,
    );
    final nextDelay = _schedule.nextDelay(scheduleContext);
    _eventSink.emit(NextCheckScheduledEvent(delay: nextDelay, scheduleContext: scheduleContext));

    return nextDelay;
  }

  static bool _isDistinctKind(InternetStatus? previous, InternetStatus current) {
    if (previous == null) return true;

    return switch ((previous, current)) {
      (Reachable(quality: final a), Reachable(quality: final b)) => a != b,
      (Unreachable(), Unreachable()) => false,
      _ => true,
    };
  }
}
