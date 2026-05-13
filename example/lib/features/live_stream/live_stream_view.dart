import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart' show AppBar, Card, Icons, Scaffold, Slider, Theme;
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
                        Slider(
                          max: ConstDurations.maxSelectableLiveStreamSlowThreshold.inMilliseconds
                              .toDouble(),
                          divisions: ConstValues.liveStreamSlowThresholdSliderDivisions,
                          value: sliderValueMs,
                          label: sliderValueMs <= 0 ? 'off' : '${sliderValueMs.round()} ms',
                          onChanged: viewModel.onSlowThresholdSliderChanged,
                          onChangeEnd: (value) =>
                              unawaited(viewModel.onSlowThresholdSliderReleased(value)),
                        ),
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
