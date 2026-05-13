import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart' show AppBar, Card, Divider, Icons, Scaffold, Theme;
import 'package:pmvvm/mvvm_builder.widget.dart';

import '../core/data/const_formatters.dart';
import '../core/widgets/core_widgets.dart';
import 'failure_inspection_view_model.dart';

class FailureInspectionView extends StatelessWidget {
  const FailureInspectionView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: FailureInspectionViewModel(),
    viewBuilder: (context, viewModel) => Scaffold(
      appBar: AppBar(title: const Text('Failure inspection')),
      body: ListView(
        padding: const .all(16),
        children: [
          const DemoIntro(
            title: 'Unreachable.failedProbes',
            description:
                'Every failed probe carries the target it hit, how long it '
                'spent before failing, and the underlying exception (if any). '
                'Targets here resolve to nowhere, so AllReachablePolicy '
                'guarantees a failure.',
          ),
          const Gap(16),
          AsyncIconActionButton(
            onPressed: viewModel.onRunCheckPressed,
            idleIcon: Icons.bug_report,
            idleLabel: 'Run check',
            busyLabel: 'Checking…',
          ),
          const Gap(16),
          ValueListenableBuilder(
            valueListenable: viewModel.lastResultListenable,
            builder: (context, result, _) =>
                result == null ? const SizedBox.shrink() : _ResultPanel(result: result),
          ),
        ],
      ),
    ),
  );
}

class _ResultPanel extends StatelessWidget {
  final InternetStatus result;

  const _ResultPanel({required this.result});

  @override
  Widget build(BuildContext context) => switch (result) {
    Reachable() => Card(
      child: Padding(
        padding: const .all(16),
        child: StatusBadge(internetStatus: result),
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
            Text('Failed probes', style: Theme.of(context).textTheme.titleMedium),
            for (final (index, probe) in failedProbes.indexed) ...[
              if (index > 0) const Divider(),
              _FailedProbeRow(probe: probe),
            ],
          ],
        ),
      ),
    ),
  };
}

class _FailedProbeRow extends StatelessWidget {
  final ProbeResult probe;

  const _FailedProbeRow({required this.probe});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: .start,
      children: [
        Text(probe.target.uri.toString(), style: Theme.of(context).textTheme.bodyMedium),
        Text(
          'Failed after ${ConstFormatters.humanReadableDuration(probe.responseTime)} '
          '(timeout: ${ConstFormatters.humanReadableDuration(probe.target.timeout)})',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          'Cause: ${ConstFormatters.describeProbeError(probe.error)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
