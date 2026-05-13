import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart'
    show AppBar, Card, Icon, Icons, ListTile, MaterialPageRoute, Navigator, Scaffold;
import 'package:pmvvm/mvvm_builder.widget.dart';

import '../features/custom_targets/custom_targets_view.dart';
import '../features/failure_inspection/failure_inspection_view.dart';
import '../features/live_stream/live_stream_view.dart';
import '../features/one_shot/one_shot_view.dart';
import '../features/policy_comparison/policy_comparison_view.dart';
import 'home_view_model.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: HomeViewModel(),
    viewBuilder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('better_internet_connectivity_checker')),
      body: ListView(
        padding: const .symmetric(vertical: 8),
        children: [
          _DemoTile(
            icon: Icons.stream,
            title: 'Live status stream',
            description:
                'Subscribe to onStatusChange with connectivity_plus wired in as a recheck trigger.',
            pageBuilder: (_) => const LiveStreamView(),
          ),
          _DemoTile(
            icon: Icons.flash_on,
            title: 'One-shot check',
            description: 'Call checkOnce() and pattern-match the sealed InternetStatus.',
            pageBuilder: (_) => const OneShotView(),
          ),
          _DemoTile(
            icon: Icons.dns,
            title: 'Custom targets',
            description: 'Probe your own URL with a custom ResponseAcceptor predicate.',
            pageBuilder: (_) => const CustomTargetsView(),
          ),
          _DemoTile(
            icon: Icons.compare_arrows,
            title: 'Policy comparison',
            description: 'Run AnyReachablePolicy and AllReachablePolicy side-by-side.',
            pageBuilder: (_) => const PolicyComparisonView(),
          ),
          _DemoTile(
            icon: Icons.error_outline,
            title: 'Failure inspection',
            description: 'Drill into Unreachable.failedProbes for diagnostics.',
            pageBuilder: (_) => const FailureInspectionView(),
          ),
        ],
      ),
    ),
  );
}

class _DemoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final WidgetBuilder pageBuilder;

  const _DemoTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.pageBuilder,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const .symmetric(horizontal: 16, vertical: 4),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: pageBuilder)),
    ),
  );
}
