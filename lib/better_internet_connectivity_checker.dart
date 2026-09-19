/// Tells "the wifi icon is on" apart from "I can actually load a page right now".
///
/// Pure Dart, so it runs wherever Dart does. Hand `externalRecheckTrigger` a stream from
/// `connectivity_plus` or anything else, and checks rerun the moment the OS says the network moved.
///
/// ```dart
/// final checker = InternetConnection();
/// switch (await checker.checkOnce()) {
///   case Reachable(:final quality): print('online ($quality)');
///   case Unreachable(:final failedProbes): print('offline, ${failedProbes.length} probes failed');
/// }
/// await checker.dispose();
/// ```
library;

export 'src/data/typedefs.dart' show JitterSource, ResponseAcceptor;
export 'src/data/values.dart' show noopWithVal;
export 'src/internet_connection.dart' show InternetConnection;
export 'src/observer/connectivity_observer.dart' show ConnectivityObserver, attachObserver;
export 'src/observer/events/connectivity_event.dart'
    show
        CheckCompletedEvent,
        CheckIntervalChangedEvent,
        ConnectivityEvent,
        DisposedEvent,
        ExternalTriggerErrorEvent,
        ExternalTriggerFiredEvent,
        NextCheckScheduledEvent,
        SlowThresholdChangedEvent,
        StatusEmittedEvent;
export 'src/observer/sinks/printing_connectivity_observer.dart' show PrintingConnectivityObserver;
export 'src/policy/reachability_policy.dart' show ReachabilityPolicy;
export 'src/policy/strategies/all_reachable_policy.dart' show AllReachablePolicy;
export 'src/policy/strategies/any_reachable_policy.dart' show AnyReachablePolicy;
export 'src/policy/strategies/minimum_reachable_policy.dart' show MinimumReachablePolicy;
export 'src/probe/connectivity_probe.dart' show ConnectivityProbe;
export 'src/probe/models/probe_result.dart' show ProbeResult;
export 'src/probe/models/probe_target.dart' show ProbeTarget;
export 'src/probe/transports/http_probe.dart' show HttpProbe;
export 'src/schedule/check_schedule.dart' show CheckSchedule;
export 'src/schedule/models/schedule_context.dart' show ScheduleContext;
export 'src/schedule/strategies/exponential_backoff_schedule.dart' show ExponentialBackoffSchedule;
export 'src/schedule/strategies/fixed_interval_schedule.dart' show FixedIntervalSchedule;
export 'src/status/internet_status.dart' show InternetStatus, Reachable, Unreachable;
export 'src/status/models/connection_quality.dart' show ConnectionQuality;
