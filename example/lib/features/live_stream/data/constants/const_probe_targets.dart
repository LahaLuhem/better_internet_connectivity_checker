import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

/// Deliberately slow probe targets, so the Live-stream demo's slider has something to chew on.
///
/// The library's defaults answer in tens of milliseconds, far too quick for a 0-2000 ms slider to
/// show both [ConnectionQuality] values. These 2 serve `delay/<seconds>` endpoints that sit on the
/// request server-side, landing the response near the 1-second mark.
///
/// Only 2 operators, against the library default's wider spread. That's the demo trading
/// production-grade redundancy for predictable latency. If both go down you get an [Unreachable],
/// which is also worth seeing. Swap in any other `delay/<n>` mirror if these stop answering.
abstract final class ConstProbeTargets {
  /// 1 second is the floor `httpbin.org` takes, and no mirror does sub-second. The faster of the
  /// 2 wins under the default [AnyReachablePolicy], and the other is the backup.
  static final liveStreamSlowTargets = [
    ProbeTarget(uri: Uri.https('postman-echo.com', 'delay/1')),
    ProbeTarget(uri: Uri.https('httpbin.org', 'delay/1')),
  ];
}
