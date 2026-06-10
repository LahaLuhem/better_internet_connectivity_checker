import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// A platform-adaptive divider — Material [Divider] on Android, a full-width
/// hairline in [CupertinoColors.separator] on Cupertino.
///
/// Gap-plugging stand-in until the base library grows a `PlatformDivider`.
/// Material's [Divider] does not throw on iOS, but it paints with the Material
/// theme's colour rather than the iOS separator colour — this keeps the look
/// native on both platforms.
class PlatformDivider extends StatelessWidget {
  const PlatformDivider({super.key});

  @override
  Widget build(BuildContext context) => PlatformWidget(
    materialBuilder: (_) => const Divider(),
    cupertinoBuilder: (context) => Container(
      height: 1,
      width: double.infinity,
      margin: const .symmetric(vertical: 8),
      color: CupertinoColors.separator.resolveFrom(context),
    ),
  );
}
