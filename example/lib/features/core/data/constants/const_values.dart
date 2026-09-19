abstract final class ConstValues {
  /// HTTP 200. Spelled out here because `dart:io`'s `HttpStatus` doesn't exist on the web.
  static const httpStatusOk = 200;

  /// HTTP 300, the first non-2xx. Exclusive upper bound when accepting any 2xx.
  static const httpStatusMultipleChoices = 300;

  /// Divisions on the Custom-targets timeout slider, one stop per second.
  static const customTargetsTimeoutSliderDivisions = 14;

  /// Divisions on the Live-stream slow-threshold slider, one stop per 50 ms.
  static const liveStreamSlowThresholdSliderDivisions = 40;
}
