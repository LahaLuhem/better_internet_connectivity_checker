import 'package:flutter/cupertino.dart' show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/widgets.dart' show BuildContext, Color;
import 'package:material_ui/material_ui.dart' show Colors;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// Status palette for the demo: the Material hue on Android, the matching `CupertinoColors.system*`
/// on iOS.
///
/// Everything goes through [CupertinoDynamicColor.resolve] so the iOS colours follow light and dark
/// mode. On the Android side that's a no-op, since a plain [Color] has nothing to resolve.
abstract final class ConstTheme {
  static const statusOutlineAlpha = 0.3;

  /// [Colors.green] on Android, [CupertinoColors.systemGreen] on iOS.
  static Color green(BuildContext context) =>
      _resolve(context, material: Colors.green, cupertino: CupertinoColors.systemGreen);

  /// [Colors.orange] on Android, [CupertinoColors.systemOrange] on iOS.
  static Color orange(BuildContext context) =>
      _resolve(context, material: Colors.orange, cupertino: CupertinoColors.systemOrange);

  /// [Colors.red] on Android, [CupertinoColors.systemRed] on iOS.
  static Color red(BuildContext context) =>
      _resolve(context, material: Colors.red, cupertino: CupertinoColors.systemRed);

  /// [Colors.blueGrey] on Android, [CupertinoColors.systemGrey] on iOS.
  static Color blueGrey(BuildContext context) =>
      _resolve(context, material: Colors.blueGrey, cupertino: CupertinoColors.systemGrey);

  static Color _resolve(
    BuildContext context, {
    required Color material,
    required Color cupertino,
  }) => CupertinoDynamicColor.resolve(
    platformValue(material: material, cupertino: cupertino),
    context,
  );
}
