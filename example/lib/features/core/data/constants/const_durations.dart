abstract final class ConstDurations {
  /// Initial `ProbeTarget.timeout` shown in the Custom-targets demo.
  static const defaultCustomTargetsProbeTimeout = Duration(seconds: 3);

  /// Minimum `ProbeTarget.timeout` selectable on the Custom-targets slider.
  static const minSelectableCustomTargetsTimeout = Duration(seconds: 1);

  /// Maximum `ProbeTarget.timeout` selectable on the Custom-targets slider.
  static const maxSelectableCustomTargetsTimeout = Duration(seconds: 15);

  /// Initial `slowThreshold` shown in the Live-stream demo.
  static const defaultLiveStreamSlowThreshold = Duration(milliseconds: 300);

  /// Maximum `slowThreshold` on the Live-stream slider. The minimum is zero, which is the off state.
  static const maxSelectableLiveStreamSlowThreshold = Duration(seconds: 2);

  /// Deliberately short timeout on one Failure-inspection probe, to show per-target customising.
  static const failureInspectionShortProbeTimeout = Duration(milliseconds: 500);
}
