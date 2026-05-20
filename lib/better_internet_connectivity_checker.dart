/// Robust internet-connectivity checking — distinguishes "a network interface
/// is up" (cheap, often misleading) from "I can actually reach the public
/// internet right now" (the question users usually care about).
///
/// The package is pure Dart and works in every Dart context (CLI, server,
/// web, Flutter). Wire `connectivity_plus` (or any other signal) via the
/// `externalRecheckTrigger` parameter for snappy rechecks on OS-reported
/// network changes.
///
/// ```dart
/// import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
///
/// Future<void> main() async {
///   final checker = InternetConnection(
///     slowThreshold: const Duration(milliseconds: 500),
///   );
///   final status = await checker.checkOnce();
///   switch (status) {
///     case Reachable(:final quality):
///       print('online ($quality)');
///     case Unreachable(:final failedProbes):
///       print('offline (${failedProbes.length} probes failed)');
///   }
///   await checker.dispose();
/// }
/// ```
library;

export 'src/data/typedefs.dart' show ResponseAcceptor;
export 'src/data/values.dart' show noopWithVal;
export 'src/internet_connection.dart' show InternetConnection;
export 'src/observer/connectivity_observer.dart' show ConnectivityObserver;
export 'src/observer/sinks/printing_connectivity_observer.dart' show PrintingConnectivityObserver;
export 'src/policy/reachability_policy.dart' show ReachabilityPolicy;
export 'src/policy/strategies/all_reachable_policy.dart' show AllReachablePolicy;
export 'src/policy/strategies/any_reachable_policy.dart' show AnyReachablePolicy;
export 'src/probe/connectivity_probe.dart' show ConnectivityProbe;
export 'src/probe/models/probe_result.dart' show ProbeResult;
export 'src/probe/models/probe_target.dart' show ProbeTarget;
export 'src/probe/transports/http_probe.dart' show HttpProbe;
export 'src/status/internet_status.dart' show InternetStatus, Reachable, Unreachable;
export 'src/status/models/connection_quality.dart' show ConnectionQuality;
