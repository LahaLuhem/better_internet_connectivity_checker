import 'dart:async';

import 'data/values.dart';
import 'observer/connectivity_observer.dart';
import 'policy/reachability_policy.dart';
import 'policy/strategies/any_reachable_policy.dart';
import 'probe/connectivity_probe.dart';
import 'probe/models/probe_target.dart';
import 'probe/transports/http_probe.dart';
import 'status/internet_status.dart';
import 'status/models/connection_quality.dart';

part 'observer/sinks/silent_connectivity_observer.dart';

/// Coordinates internet-connectivity checks.
///
/// Owns three responsibilities:
///
/// 1. **One-shot checks** via [checkOnce] — runs every target through the
///    configured [ConnectivityProbe] and aggregates via the configured
///    [ReachabilityPolicy].
/// 2. **Status streaming** via [onStatusChange] — periodically checks (at
///    [checkInterval]) and emits the resulting [InternetStatus] only when its
///    kind differs from the previously emitted one.
/// 3. **External recheck triggers** — if an [Stream] is provided as the
///    constructor's `externalRecheckTrigger`, an emission on that stream
///    forces an immediate recheck. Useful for wiring `connectivity_plus` or
///    any other signal that suggests the network state changed.
///
/// Construct once per use case. There is no shared singleton — two
/// independently-configured instances coexist without interfering. Always
/// call [dispose] when finished to release the underlying stream, timer, and
/// external-trigger subscription.
final class InternetConnection {
  final List<ProbeTarget> _targets;
  Duration _checkInterval;
  Duration? _slowThreshold;
  final ReachabilityPolicy _policy;
  final ConnectivityProbe _probe;
  final Stream<void>? _externalTrigger;
  final ConnectivityObserver _observer;

  late final _statusController = StreamController<InternetStatus>.broadcast(
    onListen: _handleFirstListener,
    onCancel: _handleLastCancel,
  );
  Timer? _timer;
  StreamSubscription<void>? _triggerSubscription;
  InternetStatus? _lastStatus;
  var _disposed = false;

  /// Creates an [InternetConnection].
  ///
  /// `targets` are the URIs probed on each check. Defaults to a curated list
  /// of public reliability endpoints chosen for operator diversity and low
  /// cache surface. The list must be non-empty; passing an empty iterable
  /// trips a debug-mode `assert` (release builds silently fall through to
  /// `Unreachable` on every check).
  ///
  /// `checkInterval` is the gap between periodic status checks once
  /// [onStatusChange] has at least one listener. Defaults to
  /// [Values.defaultCheckInterval]. Adjust at runtime by assigning to the
  /// [checkInterval] setter.
  ///
  /// `slowThreshold` is the response-time cutoff above which a successful
  /// probe is classified as slow. Defaults to null (no slow classification —
  /// every reachable status reports [ConnectionQuality.good]). Adjust at
  /// runtime by assigning to the [slowThreshold] setter — preserves
  /// [lastStatus] across the change, unlike rebuilding the
  /// [InternetConnection].
  ///
  /// `policy` selects the aggregation strategy. Defaults to
  /// [AnyReachablePolicy] (any-of-N suffices).
  ///
  /// `probe` runs a single check; defaults to [HttpProbe.head]. Pass a custom
  /// probe to swap the transport (e.g. a retry-wrapping decorator, an
  /// [HttpProbe.get] for HEAD-unfriendly endpoints) or to inject a mock in
  /// tests.
  ///
  /// `externalRecheckTrigger` is an optional stream whose events force an
  /// immediate recheck regardless of the timer. Typical Flutter wiring:
  /// `Connectivity().onConnectivityChanged.map(noopWithVal)`.
  ///
  /// `observer` is an optional [ConnectivityObserver] that receives
  /// lifecycle callbacks for every status emission, check completion,
  /// external-trigger event, interval change, and dispose. Defaults to a
  /// silent observer — no events are surfaced unless one is supplied. Pass
  /// `PrintingConnectivityObserver()` for a ready-to-use default that
  /// writes each event through `dart:developer`.
  InternetConnection({
    List<ProbeTarget>? targets,
    Duration checkInterval = Values.defaultCheckInterval,
    ReachabilityPolicy policy = const AnyReachablePolicy(),
    ConnectivityObserver observer = const _SilentConnectivityObserver(),
    Duration? slowThreshold,
    ConnectivityProbe? probe,
    Stream<void>? externalRecheckTrigger,
  }) : assert(targets == null || targets.isNotEmpty, 'targets must be non-empty'),
       _targets = targets != null ? List.unmodifiable(targets) : Values.defaultProbeTargets,
       _checkInterval = checkInterval,
       _slowThreshold = slowThreshold,
       _policy = policy,
       _externalTrigger = externalRecheckTrigger,
       _observer = observer,
       _probe = probe ?? HttpProbe.head();

  /// The current periodic check interval.
  Duration get checkInterval => _checkInterval;

  /// The current slow-classification cutoff, or null when slow detection is
  /// disabled (every reachable status reports [ConnectionQuality.good]).
  Duration? get slowThreshold => _slowThreshold;

  /// The most recently observed status, or null before the first check (or
  /// after the last [onStatusChange] subscriber cancels, which suspends the
  /// periodic timer).
  InternetStatus? get lastStatus => _lastStatus;

  /// Stream of status transitions.
  ///
  /// Periodic checks start when the first listener subscribes; the timer is
  /// suspended when the last listener cancels. Emissions are deduped on
  /// status *kind* — two consecutive [Reachable] events with the same
  /// [ConnectionQuality] won't double-fire, but a flip from
  /// [ConnectionQuality.good] to [ConnectionQuality.slow] will.
  Stream<InternetStatus> get onStatusChange => _statusController.stream;

  /// Runs one check and returns the resulting status.
  ///
  /// Does not affect the periodic timer, the status stream, or [lastStatus].
  Future<InternetStatus> checkOnce() =>
      _policy.evaluate(targets: _targets, probe: _probe, slowThreshold: _slowThreshold);

  /// Updates the periodic check interval and resets any running timer.
  set checkInterval(Duration interval) {
    final previous = _checkInterval;
    _checkInterval = interval;
    _observer.onCheckIntervalChanged(previous, interval);

    if (_timer == null) return;
    _timer!.cancel();
    _timer = Timer(_checkInterval, () => unawaited(_runScheduledCheck()));
  }

  /// Updates the slow-classification cutoff.
  ///
  /// Pass `null` to disable slow classification (every reachable status
  /// will report [ConnectionQuality.good]). Does **not** reset the periodic
  /// timer, run a check, or clear [lastStatus] — the new threshold takes
  /// effect at the next scheduled or externally-triggered check. Use
  /// [checkOnce] (without affecting the stream) or wait for the next tick
  /// to see the impact.
  ///
  /// Prefer this over reconstructing the [InternetConnection] when only
  /// the threshold changes: rebuilding loses the in-memory [lastStatus],
  /// so the next emission's `previous` value (surfaced via
  /// [ConnectivityObserver.onStatusChangeEmitted]) resets to null.
  set slowThreshold(Duration? threshold) {
    final previous = _slowThreshold;
    _slowThreshold = threshold;
    _observer.onSlowThresholdChanged(previous, threshold);
  }

  /// Releases the status stream, periodic timer, and external-trigger
  /// subscription.
  ///
  /// After [dispose] returns, the instance must not be used. Calling
  /// [checkOnce] or subscribing to [onStatusChange] yields undefined
  /// behaviour.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _timer?.cancel();
    _timer = null;

    await _triggerSubscription?.cancel();
    _triggerSubscription = null;

    await _statusController.close();
    _observer.onDispose();
  }

  void _handleFirstListener() {
    _triggerSubscription ??= _externalTrigger?.listen(
      (_) {
        _observer.onExternalTriggerFired();
        unawaited(_runScheduledCheck());
      },
      // Trigger errors are surfaced via the observer seam and otherwise
      // swallowed — the trigger is best-effort and its errors must not
      // propagate to the status stream's listeners.
      onError: _observer.onExternalTriggerError,
    );

    unawaited(_runScheduledCheck());
  }

  void _handleLastCancel() {
    if (_statusController.hasListener) return;

    _timer?.cancel();
    _timer = null;

    unawaited(_triggerSubscription?.cancel());
    _triggerSubscription = null;

    _lastStatus = null;
  }

  Future<void> _runScheduledCheck() async {
    if (_disposed || !_statusController.hasListener) return;
    _timer?.cancel();

    final status = await checkOnce();
    if (_disposed || !_statusController.hasListener) return;

    _observer.onCheckCompleted(status);

    if (_isDistinctKind(_lastStatus, status)) {
      _observer.onStatusChangeEmitted(_lastStatus, status);
      _statusController.add(status);
    }
    _lastStatus = status;

    _timer = Timer(_checkInterval, () => unawaited(_runScheduledCheck()));
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
