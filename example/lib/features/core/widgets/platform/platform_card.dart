import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Card;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// A platform-adaptive card — Material [Card] on Android, and a rounded,
/// filled surface in the iOS idiom on Cupertino (which ships no native card).
///
/// Gap-plugging stand-in: `platform_adaptive_widgets` exposes no `PlatformCard`
/// (Cupertino has no `Card` to map to), so the example owns one until the base
/// library grows it. The child supplies its own padding, exactly as a Material
/// [Card] expects.
class PlatformCard extends StatelessWidget {
  /// Content of the card.
  final Widget child;

  /// Outer margin. Defaults to Material [Card]'s own default on both platforms.
  final EdgeInsetsGeometry? margin;

  const PlatformCard({required this.child, this.margin, super.key});

  /// Mirror of Material [Card]'s default margin, applied on the Cupertino branch
  /// (the Material branch lets [Card] apply its own when [margin] is null).
  static const _defaultMargin = EdgeInsets.all(4);

  @override
  Widget build(BuildContext context) => PlatformWidget(
    materialBuilder: (_) => Card(margin: margin, child: child),
    cupertinoBuilder: (context) => Padding(
      padding: margin ?? _defaultMargin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: const .all(.circular(12)),
        ),
        child: child,
      ),
    ),
  );
}
