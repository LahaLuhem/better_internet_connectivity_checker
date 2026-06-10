import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/widgets.dart';

import '../data/const_formatters.dart';
import 'platform/platform_card.dart';
import 'status_badge.dart';

class StatusSummary extends StatelessWidget {
  final InternetStatus internetStatus;

  const StatusSummary({required this.internetStatus, super.key});

  @override
  Widget build(BuildContext context) => PlatformCard(
    margin: .zero,
    child: Padding(
      padding: const .all(16),
      child: switch (internetStatus) {
        Reachable(:final responseTime, :final quality) => Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          spacing: 8,
          children: [
            StatusBadge(internetStatus: internetStatus),
            Text('Response time: ${ConstFormatters.humanReadableDuration(responseTime)}'),
            Text('Quality: ${quality.name}'),
          ],
        ),
        Unreachable(:final failedProbes) => Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          spacing: 8,
          children: [
            StatusBadge(internetStatus: internetStatus),
            Text('Failed probes: ${failedProbes.length}'),
          ],
        ),
      },
    ),
  );
}
