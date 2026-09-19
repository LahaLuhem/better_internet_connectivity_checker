import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

/// A [PlatformButton.icon] that locks itself while [onPressed] is still running.
///
/// [TapDebouncer] with a zero cooldown, so it re-arms the moment the work finishes. While locked you
/// get a [PlatformProgressIndicator] and [busyLabel] in place of the icon and label.
class AsyncIconActionButton extends StatelessWidget {
  final Future<void> Function() onPressed;
  final PlatformIcons idleIcon;
  final String idleLabel;
  final String busyLabel;

  const new({
    required this.onPressed,
    required this.idleIcon,
    required this.idleLabel,
    required this.busyLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) => TapDebouncer(
    onTap: onPressed,
    cooldown: .zero,
    builder: (_, onTap) => PlatformButton.icon(
      onPressed: onTap ?? onPressed,
      isEnabled: onTap != null,
      icon: onTap == null
          ? const SizedBox(
              width: 16,
              height: 16,
              child: PlatformProgressIndicator(
                materialProgressIndicatorData: MaterialProgressIndicatorData(strokeWidth: 2),
                cupertinoProgressIndicatorData: CupertinoProgressIndicatorData(radius: 8),
              ),
            )
          : PlatformIcon(idleIcon),
      label: Text(onTap == null ? busyLabel : idleLabel),
    ),
  );
}
