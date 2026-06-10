import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart';

import '../data/constants/core_constants.dart';
import 'platform/platform_chip.dart';

class StatusBadge extends StatelessWidget {
  final InternetStatus? internetStatus;

  const StatusBadge({required this.internetStatus, super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (internetStatus) {
      null => (
        'Not yet checked',
        ConstTheme.blueGrey(context),
        Icon(
          context.platformIcon(
            material: Icons.help_outline,
            cupertino: CupertinoIcons.question_circle,
          ),
          color: ConstTheme.blueGrey(context),
          size: 20,
        ),
      ),
      Reachable(quality: .good) => (
        'Reachable',
        ConstTheme.green(context),
        PlatformIcon(PlatformIcons.checkMarkCircle, color: ConstTheme.green(context), size: 20),
      ),
      Reachable(quality: .slow) => (
        'Reachable (slow)',
        ConstTheme.orange(context),
        Icon(
          context.platformIcon(
            material: Icons.hourglass_bottom,
            cupertino: CupertinoIcons.hourglass,
          ),
          color: ConstTheme.orange(context),
          size: 20,
        ),
      ),
      Unreachable() => (
        'Unreachable',
        ConstTheme.red(context),
        PlatformIcon(PlatformIcons.cloudErrorFilled, color: ConstTheme.red(context), size: 20),
      ),
    };

    return PlatformChip(
      avatar: icon,
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: .w600),
      ),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: ConstTheme.statusOutlineAlpha)),
    );
  }
}
