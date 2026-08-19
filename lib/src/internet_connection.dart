import 'dart:async';

import 'data/values.dart';
import 'observer/events/connectivity_event.dart';
import 'policy/reachability_policy.dart';
import 'policy/strategies/any_reachable_policy.dart';
import 'probe/connectivity_probe.dart';
import 'probe/models/probe_target.dart';
import 'probe/transports/http_probe.dart';
import 'status/internet_status.dart';
import 'status/models/connection_quality.dart';

part 'internal/event_sink.dart';
part 'internal/external_trigger_link.dart';
part 'internal/periodic_scheduler.dart';

/// Coordinates internet-connectivity checks.
///
/// Owns three responsibilities:
///
/// 1. **One-shot checks** via [checkOnce] — runs every target through the configured [ConnectivityProbe],
///     aggregated by the configured [ReachabilityPolicy].
/// 2. **Status streaming** via [onStatusChange] — checks every [checkInterval] and emits the result
///     only when its kind differs from the last emitted one.
/// 3. **External recheck triggers** — an emission on the constructor's `externalRecheckTrigger` stream
///    forces an immediate recheck. Wire `connectivity_plus` or any other network-change signal through it.
///
/// Construct once per use case; there is no shared singleton, and independent instances don't interfere.
/// Always [dispose] when finished to release the stream, timer, and trigger subscription.
final class InternetConnection {
  final List<ProbeTarget> _targets;
  Duration _checkInterval;
  Duration? _slowThreshold;
  final ReachabilityPolicy _policy;
  final ConnectivityProbe _probe;
  final Stream<void>? _externalTrigger;

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
      _scheduler.start();
    },
    onError: (error, stackTrace) {
      _eventSink.emit(ExternalTriggerErrorEvent(error, stackTrace));
    },
  );
  InternetStatus? _lastStatus;
  var _disposed = false;

  /// Creates an [InternetConnection].
  ///
  /// `targets` are the URIs probed on each check. Defaults to a curated list of public reliability
  /// endpoints (diverse operators, low cache surface). Must be non-empty. An empty list trips a debug-mode
  /// `assert` (release builds fall through to `Unreachable` every check).
  ///
  /// `checkInterval` is the gap between periodic checks once [onStatusChange] has a listener.
  /// Defaults to [Values.defaultCheckInterval]; change it at runtime via the [_checkInterval] setter.
  ///
  /// `slowThreshold` is the response-time cutoff above which a successful probe is classified as slow.
  /// Defaults to null (no classification — every reachable status is [ConnectionQuality.good]).
  /// The [_slowThreshold] setter changes it at runtime while preserving [lastStatus], unlike rebuilding.
  ///
  /// `policy` selects the aggregation strategy. Defaults to [AnyReachablePolicy] (any-of-N).
  ///
  /// `probe` runs a single check; defaults to [HttpProbe.head]. Pass a custom probe to swap the
  /// transport (a retry decorator, [HttpProbe.get] for HEAD-unfriendly endpoints) or inject a mock.
  ///
  /// `externalRecheckTrigger` is an optional stream whose events force an immediate recheck. Typical
  /// Flutter wiring: `Connectivity().onConnectivityChanged.map(noopWithVal)`.
  ///
  /// To observe lifecycle events, subscribe to [events] or wire a `ConnectivityObserver` via the
  /// top-level `attachObserver`.
  new({
    List<ProbeTarget>? targets,
    this._checkInterval = Values.defaultCheckInterval,
    this._policy = const AnyReachablePolicy(),
    this._slowThreshold,
    ConnectivityProbe? probe,
    Stream<void>? externalRecheckTrigger,
  }) : assert(targets == null || targets.isNotEmpty, 'targets must be non-empty'),
       _targets = targets != null ? List.unmodifiable(targets) : Values.defaultProbeTargets,
       _externalTrigger = externalRecheckTrigger,
       _probe = probe ?? HttpProbe.head();

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
  /// Does not affect the periodic timer, the status stream, or [lastStatus].
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

    return _checkInterval;
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
