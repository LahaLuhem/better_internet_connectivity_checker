import '../probe/models/probe_target.dart';
import 'models/const_uri.dart';

/// Defaults for the package's own classes. Not exported, so configure these through constructor
/// arguments instead.
abstract final class Values {
  /// `InternetConnection.checkInterval`'s default.
  static const defaultCheckInterval = Duration(seconds: 10);

  /// [ProbeTarget.timeout]'s default.
  static const defaultProbeTimeout = Duration(seconds: 3);

  /// One 60 fps frame, which is where `attachObserver`'s watchdog starts calling a callback slow.
  static const defaultSlowCallbackThreshold = Duration(milliseconds: 16);

  /// [ProbeTarget.headers]'s default.
  static const defaultProbeHeaders = <String, String>{};

  /// HTTP 200. Spelled out here because `dart:io`'s `HttpStatus` doesn't exist on the web.
  static const httpStatusOk = 200;

  /// What `InternetConnection` probes when you don't hand it any targets.
  ///
  /// 3 operators rather than 3 URLs on one, so a single provider's outage can't fail the
  /// lot: Cloudflare, OpenStreetMap behind Fastly, Open-Meteo on Hetzner. All 3 answer HEAD with
  /// 200, allow CORS, and send nothing cacheable that could mask an outage.
  static const defaultProbeTargets = <ProbeTarget>[
    ProbeTarget(uri: ConstUri('https://one.one.one.one')),
    ProbeTarget(uri: ConstUri('https://api.openstreetmap.org/api/0.6/capabilities')),
    ProbeTarget(uri: ConstUri('https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0')),
  ];
}

/// Takes anything, does nothing. Mostly for turning a `Stream<X>` into a `Stream<void>` with
/// `.map(noopWithVal)`.
// A getter rather than a top-level final, which sidesteps
// `prefer_function_declarations_over_variables`. The empty body is the whole point.
// ignore: no-empty-block
void Function(Object?) get noopWithVal => (_) {};
