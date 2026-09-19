import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart' show Theme;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '../core/data/constants/core_constants.dart';
import '../core/widgets/core_widgets.dart';
import 'live_stream_view_model.dart';

class LiveStreamView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: LiveStreamViewModel(),
    viewBuilder: (context, viewModel) => PlatformScaffold(
      appBarData: const PlatformAppBar(title: Text('Live status stream')),
      body: SafeArea(
        child: ListView(
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
                  PlatformCard(
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
            PlatformCard(
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
                                ? 'Disabled, so every reachable status reports good.'
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
              idleIcon: PlatformIcons.refresh,
              idleLabel: 'Force recheck (checkOnce)',
              busyLabel: 'Rechecking…',
            ),
          ],
        ),
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

/// Slider sitting on a band that fades orange (expect slow) to green (expect good), because probe
/// response times wobble and so does the real flip point. Same colours as the status badges.
class _ThresholdSlider extends StatelessWidget {
  const new({required this.viewModel, required this.sliderValueMs});

  /// Visual band height. Eyeball against the slider knob diameter.
  static const _bandHeight = 20.0;

  /// Where the band stops being solidly "slow", as a fraction of the slider range. The `delay/1`
  /// targets nominally take 1000 ms, and eyeballing puts the faster one between 800 and 1200, so the
  /// fuzzy middle is 40% to 60% of the 0-2000 ms range.
  static const _errorBandLowerStop = 0.4;

  /// Where it starts being solidly "good". See [_errorBandLowerStop] for where the numbers come from.
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
            colors:
                [
                      ConstTheme.orange(context),
                      ConstTheme.orange(context),
                      ConstTheme.green(context),
                      ConstTheme.green(context),
                    ]
                    .map((colour) => colour.withValues(alpha: ConstTheme.statusOutlineAlpha))
                    .toList(growable: false),
            stops: const [0, _errorBandLowerStop, _errorBandUpperStop, 1],
          ),
        ),
      ),
      PlatformSlider(
        max: ConstDurations.maxSelectableLiveStreamSlowThreshold.inMilliseconds.toDouble(),
        divisions: ConstValues.liveStreamSlowThresholdSliderDivisions,
        value: sliderValueMs,
        onChanged: viewModel.onSlowThresholdSliderChanged,
        onChangeEnd: (value) => unawaited(viewModel.onSlowThresholdSliderReleased(value)),
        materialSliderData: MaterialSliderData(
          label: sliderValueMs <= 0 ? 'off' : '${sliderValueMs.round()} ms',
        ),
      ),
    ],
  );
}
