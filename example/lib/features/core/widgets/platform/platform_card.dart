import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Card;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// Material [Card] on Android, a rounded filled surface on iOS, which has no card of its own.
///
/// `platform_adaptive_widgets` has no `PlatformCard` for exactly that reason, so the example carries
/// one until it does. The child brings its own padding, same as a Material [Card] expects.
class const PlatformCard({
  /// Content of the card.
  required final Widget child,

  /// Outer margin. Defaults to Material [Card]'s own default on both platforms.
  final EdgeInsetsGeometry? margin,

  super.key,
}) extends StatelessWidget {
  /// Copy of Material [Card]'s default, for the Cupertino branch. The Material branch lets [Card]
  /// apply its own.
  static const _defaultMargin = EdgeInsets.all(4);

  /// Shared by the Cupertino branch's fill and its clip, so background and clip path stay in step.
  static const _cornerRadius = BorderRadius.all(.circular(12));

  @override
  Widget build(BuildContext context) => PlatformWidget(
    materialBuilder: (_) => Card(margin: margin, clipBehavior: .antiAlias, child: child),
    cupertinoBuilder: (context) => Container(
      margin: margin ?? _defaultMargin,
      clipBehavior: .antiAlias,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: _cornerRadius,
      ),
      child: child,
    ),
  );
}
