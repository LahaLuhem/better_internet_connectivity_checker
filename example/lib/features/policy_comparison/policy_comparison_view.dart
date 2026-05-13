import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart'
    show AppBar, Card, Icons, Scaffold, SwitchListTile, Theme;
import 'package:pmvvm/mvvm_builder.widget.dart';

import '../core/data/const_formatters.dart';
import '../core/widgets/core_widgets.dart';
import 'policy_comparison_view_model.dart';

class PolicyComparisonView extends StatelessWidget {
  const PolicyComparisonView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: PolicyComparisonViewModel(),
    viewBuilder: (context, viewModel) => Scaffold(
      appBar: AppBar(title: const Text('Policy comparison')),
      body: ListView(
        padding: const .all(16),
        children: [
          const DemoIntro(
            title: 'AnyReachablePolicy vs AllReachablePolicy',
            description:
                'Both checkers receive the same target list. Toggle the bogus '
                'URL to see why "any" forgives a broken endpoint and "all" '
                'does not.',
          ),
          const Gap(16),
          ValueListenableBuilder(
            valueListenable: viewModel.shouldIncludeBogusTargetListenable,
            builder: (context, shouldIncludeBogusTarget, _) => SwitchListTile(
              title: const Text('Include unreachable bogus URL'),
              subtitle: const Text('this-domain-definitely-does-not-resolve.invalid'),
              value: shouldIncludeBogusTarget,
              onChanged: (value) => viewModel.onIncludeBogusTargetToggled(value: value),
            ),
          ),
          const Gap(8),
          AsyncIconActionButton(
            onPressed: viewModel.onRunBothPressed,
            idleIcon: Icons.play_arrow,
            idleLabel: 'Run both policies',
            busyLabel: 'Checking…',
          ),
          const Gap(16),
          ValueListenableBuilder(
            valueListenable: viewModel.resultsListenable,
            builder: (context, results, _) => Column(
              spacing: 16,
              children: [
                _PolicyCard(
                  title: 'AnyReachablePolicy (default)',
                  blurb: 'Succeeds on the first probe that succeeds.',
                  result: results?.any,
                ),
                _PolicyCard(
                  title: 'AllReachablePolicy',
                  blurb: 'Every probe must succeed.',
                  result: results?.all,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PolicyCard extends StatelessWidget {
  final String title;
  final String blurb;
  final InternetStatus? result;

  const _PolicyCard({required this.title, required this.blurb, required this.result});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const .all(16),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(blurb, style: Theme.of(context).textTheme.bodySmall),
          StatusBadge(internetStatus: result),
          if (result case final r?) _ResultDetail(result: r),
        ],
      ),
    ),
  );
}

class _ResultDetail extends StatelessWidget {
  final InternetStatus result;

  const _ResultDetail({required this.result});

  @override
  Widget build(BuildContext context) => switch (result) {
    Reachable(:final responseTime) => Text(
      'Response time: ${ConstFormatters.humanReadableDuration(responseTime)}',
    ),
    Unreachable(:final failedProbes) => Text(
      '${failedProbes.length} probe(s) failed: '
      '${failedProbes.map((probe) => probe.target.uri.host).join(', ')}',
    ),
  };
}
