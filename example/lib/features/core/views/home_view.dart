import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons, MaterialPageRoute, Navigator;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/custom_targets/custom_targets_view.dart';
import '/features/failure_inspection/failure_inspection_view.dart';
import '/features/live_stream/live_stream_view.dart';
import '/features/one_shot/one_shot_view.dart';
import '/features/policy_comparison/policy_comparison_view.dart';
import '../widgets/platform/platform_card.dart';
import 'home_view_model.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: HomeViewModel(),
    viewBuilder: (context, _) => PlatformScaffold(
      appBarData: const PlatformAppBar(title: Text('better_internet_connectivity_checker')),
      body: SafeArea(
        child: ListView(
          padding: const .symmetric(vertical: 8),
          children: [
            _DemoTile(
              icon: Icon(
                context.platformIcon(
                  material: Icons.stream,
                  cupertino: CupertinoIcons.dot_radiowaves_left_right,
                ),
              ),
              title: 'Live status stream',
              description:
                  'Subscribe to onStatusChange with connectivity_plus wired in as a recheck trigger.',
              pageBuilder: (_) => const LiveStreamView(),
            ),
            _DemoTile(
              icon: const PlatformIcon(PlatformIcons.bolt),
              title: 'One-shot check',
              description: 'Call checkOnce() and pattern-match the sealed InternetStatus.',
              pageBuilder: (_) => const OneShotView(),
            ),
            _DemoTile(
              icon: Icon(
                context.platformIcon(material: Icons.dns, cupertino: CupertinoIcons.globe),
              ),
              title: 'Custom targets',
              description: 'Probe your own URL with a custom ResponseAcceptor predicate.',
              pageBuilder: (_) => const CustomTargetsView(),
            ),
            _DemoTile(
              icon: Icon(
                context.platformIcon(
                  material: Icons.compare_arrows,
                  cupertino: CupertinoIcons.arrow_right_arrow_left,
                ),
              ),
              title: 'Policy comparison',
              description: 'Run AnyReachablePolicy and AllReachablePolicy side-by-side.',
              pageBuilder: (_) => const PolicyComparisonView(),
            ),
            _DemoTile(
              icon: Icon(
                context.platformIcon(
                  material: Icons.error_outline,
                  cupertino: CupertinoIcons.exclamationmark_circle,
                ),
              ),
              title: 'Failure inspection',
              description: 'Drill into Unreachable.failedProbes for diagnostics.',
              pageBuilder: (_) => const FailureInspectionView(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DemoTile extends StatelessWidget {
  final Widget icon;
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
  Widget build(BuildContext context) => PlatformCard(
    margin: const .symmetric(horizontal: 16, vertical: 4),
    child: PlatformListTile(
      leading: icon,
      title: Text(title),
      subtitle: Text(description),
      trailing: Icon(
        context.platformIcon(
          material: Icons.chevron_right,
          cupertino: CupertinoIcons.right_chevron,
        ),
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: pageBuilder)),
    ),
  );
}
