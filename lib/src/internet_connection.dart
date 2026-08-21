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

/// Coordinates internet-connectivity checks.
///
/// Owns three responsibilities:
///
/// 1. **One-shot checks** via [checkOnce] — runs every target through the configured [ConnectivityProbe],
///     aggregated by the configured [ReachabilityPolicy].
/// 2. **Status streaming** via [onStatusChange] — checks on the cadence the configured [CheckSchedule]
///     sets and emits the result only when its kind differs from the last emitted one.
/// 3. **External recheck triggers** — an emission on the constructor's `externalRecheckTrigger` stream
///    forces an immediate recheck. Wire `connectivity_plus` or any other network-change signal through it.
///
/// Construct once per use case; there is no shared singleton, and independent instances don't interfere.
/// Always [dispose] when finished to release the stream, timer, and trigger subscription.
final class InternetConnection({
  /// The URIs probed on each check.
  ///
  /// Defaults to three public endpoints, one per operator, so no single provider's outage can fail
  /// every probe. Must be non-empty: an empty list trips a debug-mode `assert`, and release builds
  /// fall through to `Unreachable` every check.
  List<ProbeTarget>? targets,

  /// The gap between periodic checks once [onStatusChange] has a listener.
  ///
  /// Change it at runtime via the [checkInterval] setter. Under a non-fixed `schedule` this is the
  /// base the schedule derives each gap from, not the gap itself.
  var Duration _checkInterval = Values.defaultCheckInterval,

  /// The aggregation strategy. Defaults to [AnyReachablePolicy] (any-of-N).
  final ReachabilityPolicy _policy = const AnyReachablePolicy(),

  /// Sets the gap before each next check.
  ///
  /// Defaults to [FixedIntervalSchedule], which keeps `checkInterval` between every check. Pass
  /// [ExponentialBackoffSchedule] to widen the gap while checks keep failing, at the cost of
  /// noticing recovery later.
  final CheckSchedule _schedule = const FixedIntervalSchedule(),

  /// The response-time cutoff above which a successful probe is classified as slow.
  ///
  /// Defaults to null (no classification — every reachable status is [ConnectionQuality.good]). The
  /// [slowThreshold] setter changes it at runtime while preserving [lastStatus], unlike rebuilding.
  var Duration? _slowThreshold,

  /// Runs a single check; defaults to [HttpProbe.head].
  ///
  /// Pass a custom probe to swap the transport ([HttpProbe.get] for HEAD-unfriendly endpoints, a
  /// retry wrapper, a DNS or TCP probe) or inject a mock. Whatever you pass is capped at each
  /// target's [ProbeTarget.timeout], so a retry wrapper has to fit its attempts inside that budget.
  ConnectivityProbe? probe,

  /// An optional stream whose events force an immediate recheck.
  ///
  /// Typical Flutter wiring: `Connectivity().onConnectivityChanged.map(noopWithVal)`.
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
  ///
  /// To observe lifecycle events, subscribe to [events] or wire a `ConnectivityObserver` via the
  /// top-level `attachObserver`.
  this : assert(targets == null || targets.isNotEmpty, 'targets must be non-empty');

  /// The current periodic check interval.
  Duration get checkInterval => _checkInterval;

  /// The current slow-classification cutoff, or null when slow detection is disabled
  /// (every reachable status reports [ConnectionQuality.good]).
  Duration? get slowThreshold => _slowThreshold;

  /// The most recently observed status, or null before the first check
  /// (or after the last [onStatusChange] subscriber cancels, which suspends the periodic timer).
  InternetStatus? get lastStatus => _lastStatus;

  /// Stream of status transitions.
  ///
  /// Periodic checks start on the first listener and suspend when the last one cancels. Emissions
  /// are deduped on status *kind*: two consecutive [Reachable]s of the same [ConnectionQuality] won't
  /// double-fire, but a [ConnectionQuality.good] → [ConnectionQuality.slow] flip will.
  Stream<InternetStatus> get onStatusChange => _statusController.stream;

  /// Stream of internal diagnostic events.
  ///
  /// Surfaces lifecycle activity (status emissions, check completions, external triggers, config changes, dispose)
  /// microtask-deferred from the caller's frame. The deferral keeps the scheduler on cadence while a
  /// listener's synchronous work per event stays below the check interval, but it cannot insulate the
  /// event loop: synchronous blocking work in a listener still blocks the whole isolate for its duration
  /// (see the threading notes on `ConnectivityObserver`). [onStatusChange] is unaffected and stays
  /// synchronous — status emission must not wait on diagnostic work.
  ///
  /// Emissions racing [dispose] are best-effort: anything queued after the sink closes is dropped.
  /// The terminal [DisposedEvent] always reaches subscribers attached when [dispose] is called.
  Stream<ConnectivityEvent> get events => _eventSink.stream;

  /// Runs one check and returns the resulting status.
  ///
  /// Each probe is capped at its target's [ProbeTarget.timeout], so the check takes at most the
  /// longest of those (the built-in policies run their probes in parallel).
  ///
  /// Does not affect the periodic timer, the status stream, [lastStatus], or the failure streak the
  /// [CheckSchedule] sees.
  Future<InternetStatus> checkOnce() =>
      _policy.evaluate(targets: _targets, probe: _probe, slowThreshold: _slowThreshold);

  /// Updates the periodic check interval and resets any running timer.
  set checkInterval(Duration interval) {
    final previous = _checkInterval;
    _checkInterval = interval;
    _eventSink.emit(CheckIntervalChangedEvent(previous: previous, next: interval));
    _scheduler.rescheduleAfter(interval);
  }

  /// Updates the slow-classification cutoff.
  ///
  /// Pass `null` to disable slow classification (every reachable status reports [ConnectionQuality.good]).
  /// Does **not** reset the timer, run a check, or clear [lastStatus] — the new threshold takes effect
  /// at the next scheduled or triggered check.
  ///
  /// Prefer this over rebuilding the [InternetConnection] when only the threshold changes: rebuilding
  /// loses the in-memory [lastStatus], resetting the next [StatusEmittedEvent]'s `previous` to null.
  set slowThreshold(Duration? threshold) {
    final previous = _slowThreshold;
    _slowThreshold = threshold;
    _eventSink.emit(SlowThresholdChangedEvent(previous: previous, next: threshold));
  }

  /// Releases the status stream, periodic timer, and external-trigger subscription.
  ///
  /// After [dispose] returns the instance must not be used: [checkOnce] or subscribing to [onStatusChange]
  /// yields undefined behaviour.
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
