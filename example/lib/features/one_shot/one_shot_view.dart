import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart' show AppBar, Card, Icons, Scaffold, Theme;
import 'package:pmvvm/mvvm_builder.widget.dart';

import '../core/data/const_formatters.dart';
import '../core/widgets/core_widgets.dart';
import 'one_shot_view_model.dart';

class OneShotView extends StatelessWidget {
  const OneShotView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: OneShotViewModel(),
    viewBuilder: (context, viewModel) => Scaffold(
      appBar: AppBar(title: const Text('One-shot check')),
      body: ListView(
        padding: const .all(16),
        children: [
          const DemoIntro(
            title: 'checkOnce()',
            description:
                'Runs a single check against the default probe targets and '
                'returns a sealed InternetStatus. The pattern-match below is '
                'exhaustive — adding a future variant would be a compile error.',
          ),
          const Gap(16),
          AsyncIconActionButton(
            onPressed: viewModel.onRunCheckPressed,
            idleIcon: Icons.play_arrow,
            idleLabel: 'Run check',
            busyLabel: 'Checking…',
          ),
          const Gap(16),
          ValueListenableBuilder(
            valueListenable: viewModel.lastResultListenable,
            builder: (context, result, _) => _ResultPanel(result: result),
          ),
        ],
      ),
    ),
  );
}

class _ResultPanel extends StatelessWidget {
  final InternetStatus? result;

  const _ResultPanel({required this.result});

  @override
  Widget build(BuildContext context) => switch (result) {
    null => Card(
      child: Padding(
        padding: const .all(16),
        child: Text(
          'Press the button to run a check.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ),
    Reachable(:final responseTime, :final quality) => Card(
      child: Padding(
        padding: const .all(16),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 8,
          children: [
            StatusBadge(internetStatus: result),
            Text(
              'Winning probe response time: ${ConstFormatters.humanReadableDuration(responseTime)}',
            ),
            Text('Connection quality: ${quality.name}'),
          ],
        ),
      ),
    ),
    Unreachable(:final failedProbes) => Card(
      child: Padding(
        padding: const .all(16),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 8,
          children: [
            StatusBadge(internetStatus: result),
            Text(
              '${failedProbes.length} probe(s) failed — see the '
              'Failure-inspection demo for full diagnostics.',
            ),
          ],
        ),
      ),
    ),
  };
}
