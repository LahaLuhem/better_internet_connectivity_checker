import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart' show Theme;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '../core/data/const_formatters.dart';
import '../core/widgets/core_widgets.dart';
import 'data/constants/const_schedule_comparison.dart';
import 'schedule_comparison_view_model.dart';

class ScheduleComparisonView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: ScheduleComparisonViewModel(),
    viewBuilder: (context, viewModel) => PlatformScaffold(
      appBarData: const PlatformAppBar(title: Text('Schedule comparison')),
      body: SafeArea(
        child: ListView(
          padding: const .all(16),
          children: [
            const DemoIntro(
              title: 'FixedIntervalSchedule vs ExponentialBackoffSchedule',
              description:
                  'Two checkers share one target and one base interval. Each row '
                  'is a NextCheckScheduledEvent: the delay the schedule asked for, '
                  'and the failure streak behind it. Flip reachability to watch both '
                  'ladders reset; flip jitter to spread the backoff rungs.',
            ),
            const Gap(16),
            ValueListenableBuilder(
              valueListenable: viewModel.shouldProbeReachableTargetListenable,
              builder: (context, shouldProbeReachableTarget, _) => PlatformListTile(
                title: const Text('Probe a reachable target'),
                subtitle: Text(
                  shouldProbeReachableTarget
                      ? 'one.one.one.one'
                      : 'this-domain-definitely-does-not-resolve.invalid',
                ),
                trailing: PlatformSwitch(
                  value: shouldProbeReachableTarget,
                  onChanged: (value) => viewModel.onTargetReachabilityToggled(value: value),
                ),
                onTap: () =>
                    viewModel.onTargetReachabilityToggled(value: !shouldProbeReachableTarget),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: viewModel.shouldJitterListenable,
              builder: (context, shouldJitter, _) => PlatformListTile(
                title: const Text('Spread the delays (jitter)'),
                subtitle: Text(
                  shouldJitter
                      ? 'randomizationFactor: ${ConstScheduleComparison.demoRandomizationFactor} '
                            '(the package default)'
                      : 'randomizationFactor: 0 (exact delays)',
                ),
                trailing: PlatformSwitch(
                  value: shouldJitter,
                  onChanged: (value) => viewModel.onJitterToggled(value: value),
                ),
                onTap: () => viewModel.onJitterToggled(value: !shouldJitter),
              ),
            ),
            const Gap(16),
            ValueListenableBuilder(
              valueListenable: viewModel.ladderStateListenable,
              builder: (context, ladderState, _) => Column(
                spacing: 16,
                children: [
                  _LadderCard(
                    title: 'FixedIntervalSchedule (default)',
                    blurb:
                        'Same gap every check: '
                        '${ConstFormatters.humanReadableDuration(ConstScheduleComparison.baseInterval)}.',
                    rungs: ladderState.fixed,
                  ),
                  _LadderCard(
                    title: 'ExponentialBackoffSchedule',
                    blurb:
                        'Doubles from the second failure, capped at '
                        '${ConstFormatters.humanReadableDuration(ConstScheduleComparison.maxBackoffDelay)}.',
                    rungs: ladderState.backoff,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LadderCard extends StatelessWidget {
  final String title;
  final String blurb;
  final List<ScheduledRung> rungs;

  const new({required this.title, required this.blurb, required this.rungs});

  @override
  Widget build(BuildContext context) => PlatformCard(
    child: Padding(
      padding: const .all(16),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(blurb, style: Theme.of(context).textTheme.bodySmall),
          if (rungs.isEmpty)
            const Text('Waiting for the first check…')
          else
            for (final rung in rungs) _RungRow(rung: rung),
        ],
      ),
    ),
  );
}

class _RungRow extends StatelessWidget {
  final ScheduledRung rung;

  const new({required this.rung});

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      PlatformChip(label: Text('next in ${ConstFormatters.humanReadableDuration(rung.delay)}')),
      Text(
        rung.consecutiveFailures == 0
            ? 'connection healthy'
            : '${rung.consecutiveFailures} consecutive failure(s)',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
