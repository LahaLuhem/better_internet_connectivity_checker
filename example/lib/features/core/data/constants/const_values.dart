abstract final class ConstValues {
  /// HTTP 200 (OK). Defined locally because `dart:io.HttpStatus` is unavailable
  /// on the web platform — importing it would break web compilation.
  static const httpStatusOk = 200;

  /// HTTP 300 (Multiple Choices) — the first non-2xx status. Used as the
  /// exclusive upper bound when accepting any 2xx response.
  static const httpStatusMultipleChoices = 300;

  /// Number of divisions on the Custom-targets timeout slider — one stop per
  /// second across the selectable range.
  static const customTargetsTimeoutSliderDivisions = 14;

  /// Number of divisions on the Live-stream slow-threshold slider — 50 ms
  /// stops across the selectable range.
  static const liveStreamSlowThresholdSliderDivisions = 40;
}
