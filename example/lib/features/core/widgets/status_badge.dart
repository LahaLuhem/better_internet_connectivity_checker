import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Chip, Colors, Icons;

import '../data/constants/core_constants.dart';

class StatusBadge extends StatelessWidget {
  final InternetStatus? internetStatus;

  const StatusBadge({required this.internetStatus, super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (internetStatus) {
      null => ('Not yet checked', Colors.blueGrey, Icons.help_outline),
      Reachable(quality: .good) => ('Reachable', Colors.green, Icons.check_circle_outline),
      Reachable(quality: .slow) => ('Reachable (slow)', Colors.orange, Icons.hourglass_bottom),
      Unreachable() => ('Unreachable', Colors.red, Icons.cloud_off),
    };

    return Chip(
      avatar: Icon(icon, color: color, size: 20),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: .w600),
      ),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: ConstTheme.statusOutlineAlpha)),
    );
  }
}
