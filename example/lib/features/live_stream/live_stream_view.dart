import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart'
    show AppBar, Card, Colors, Icons, Scaffold, Slider, Theme;
import 'package:pmvvm/mvvm_builder.widget.dart';

import '../core/data/constants/core_constants.dart';
import '../core/widgets/core_widgets.dart';
import 'live_stream_view_model.dart';

class LiveStreamView extends StatelessWidget {
  const LiveStreamView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: LiveStreamViewModel(),
    viewBuilder: (context, viewModel) => Scaffold(
      appBar: AppBar(title: const Text('Live status stream')),
      body: ListView(
        padding: const .all(16),
        children: [
          const DemoIntro(
            title: 'onStatusChange',
            description:
                'The stream emits on every status-kind transition. '
                'connectivity_plus is wired in as an external recheck trigger '
                'so OS-reported network changes force an immediate recheck.',
          ),
          const Gap(16),
          ValueListenableBuilder(
            valueListenable: viewModel.streamStateListenable,
            builder: (context, streamState, _) => Column(
              crossAxisAlignment: .stretch,
              spacing: 16,
              children: [
                StatusBadge(internetStatus: streamState?.status),
                Card(
                  child: Padding(
                    padding: const .all(16),
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: 8,
                      children: [
                        Text('Stream stats', style: Theme.of(context).textTheme.titleMedium),
                        Text('Transitions received: ${streamState?.transitions ?? 0}'),
                        Text('Last update: ${_formatTimestamp(streamState?.lastUpdate)}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),
          Card(
            child: Padding(
              padding: const .all(16),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text('Slow threshold', style: Theme.of(context).textTheme.titleMedium),
                  ValueListenableBuilder(
                    valueListenable: viewModel.sliderValueMillisListenable,
                    builder: (context, sliderValueMs, _) => Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          sliderValueMs <= 0
                              ? 'Disabled — every reachable status reports good.'
                              : 'Above ${sliderValueMs.round()} ms a probe is classified as slow.',
                        ),
                        const Gap(4),
                        Text(
                          'Approximate hint: probes nominally delay ~1 s, so the '
                          'transition lands fuzzily around the shaded band.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        _ThresholdSlider(viewModel: viewModel, sliderValueMs: sliderValueMs),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),
          AsyncIconActionButton(
            onPressed: viewModel.onForceRecheckPressed,
            idleIcon: Icons.refresh,
            idleLabel: 'Force recheck (checkOnce)',
            busyLabel: 'Rechecking…',
          ),
        ],
      ),
    ),
  );

  String _formatTimestamp(DateTime? at) {
    if (at == null) return '—';
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    final ss = at.second.toString().padLeft(2, '0');

    return '$hh:$mm:$ss';
  }
}

/// Slider with an "expected slow" → "expected good" gradient band behind
/// it. The band is flat orange below the [_errorBandLowerStop], flat
/// green above the [_errorBandUpperStop], and smoothly transitions
/// between in the middle — visually honest about where the actual
/// quality flip is likely to land given probe response-time variance.
/// Colours match the status badges: orange for slow, green for good (see
/// `status_badge.dart`).
class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({required this.viewModel, required this.sliderValueMs});

  /// Visual band height. Eyeball against the slider knob diameter.
  static const _bandHeight = 20.0;

  /// Lower edge of the response-time "error band", expressed as a
  /// fraction of the slider's 0–[ConstDurations.maxSelectableLiveStreamSlowThreshold]
  /// range. Below this, response time is confidently above the threshold
  /// → `slow`.
  ///
  /// Estimate: the configured `/delay/1` probe targets nominally respond
  /// in 1000 ms; TLS / TCP overhead and network jitter add variance.
  /// Casual sampling lands the faster of the two between 800 ms and
  /// 1200 ms, so the band brackets 1000 ms ± 200 ms ≈ 40 %–60 % of the
  /// 0–2000 ms slider range.
  static const _errorBandLowerStop = 0.4;

  /// Upper edge of the error band — 60 % of the slider range = 1200 ms.
  /// Above this, response time is confidently below the threshold →
  /// `good`. See [_errorBandLowerStop] for the variance estimate.
  static const _errorBandUpperStop = 0.6;

  final LiveStreamViewModel viewModel;
  final double sliderValueMs;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: .center,
    children: [
      Container(
        height: _bandHeight,
        width: double.infinity,
        margin: const .symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          gradient: LinearGradient(
            colors: [Colors.orange, Colors.orange, Colors.green, Colors.green]
                .map((colour) => colour.withValues(alpha: ConstTheme.statusOutlineAlpha))
                .toList(growable: false),
            stops: const [0, _errorBandLowerStop, _errorBandUpperStop, 1],
          ),
        ),
      ),
      Slider(
        max: ConstDurations.maxSelectableLiveStreamSlowThreshold.inMilliseconds.toDouble(),
        divisions: ConstValues.liveStreamSlowThresholdSliderDivisions,
        value: sliderValueMs,
        label: sliderValueMs <= 0 ? 'off' : '${sliderValueMs.round()} ms',
        onChanged: viewModel.onSlowThresholdSliderChanged,
        onChangeEnd: (value) => unawaited(viewModel.onSlowThresholdSliderReleased(value)),
      ),
    ],
  );
}
