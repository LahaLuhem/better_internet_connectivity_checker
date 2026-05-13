abstract final class ConstDurations {
  /// Initial `ProbeTarget.timeout` shown in the Custom-targets demo.
  static const defaultCustomTargetsProbeTimeout = Duration(seconds: 3);

  /// Minimum `ProbeTarget.timeout` selectable on the Custom-targets slider.
  static const minSelectableCustomTargetsTimeout = Duration(seconds: 1);

  /// Maximum `ProbeTarget.timeout` selectable on the Custom-targets slider.
  static const maxSelectableCustomTargetsTimeout = Duration(seconds: 15);

  /// Initial `slowThreshold` shown in the Live-stream demo.
  static const defaultLiveStreamSlowThreshold = Duration(milliseconds: 300);

  /// Maximum `slowThreshold` selectable on the Live-stream slider. The
  /// minimum is implicitly zero (the off state — no slow detection).
  static const maxSelectableLiveStreamSlowThreshold = Duration(seconds: 2);

  /// Shorter per-target timeout configured on one of the Failure-inspection
  /// probes to illustrate per-target timeout customisation.
  static const failureInspectionShortProbeTimeout = Duration(milliseconds: 500);
}
