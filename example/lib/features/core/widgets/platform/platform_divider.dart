import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// Material [Divider] on Android, a full-width hairline in [CupertinoColors.separator] on iOS.
///
/// Material's [Divider] doesn't throw on iOS, it just paints the wrong colour, so this sticks around
/// until `platform_adaptive_widgets` grows a `PlatformDivider`.
class PlatformDivider extends StatelessWidget {
  const new({super.key});

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
