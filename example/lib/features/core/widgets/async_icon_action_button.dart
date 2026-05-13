import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show CircularProgressIndicator, ElevatedButton, Icon;
import 'package:tap_debouncer/tap_debouncer.dart';

/// An [ElevatedButton.icon] that locks itself while [onPressed] is in flight.
///
/// Wraps [TapDebouncer] with `cooldown: Duration.zero` so the button re-arms
/// as soon as the async work completes. While locked, the icon is swapped for
/// a [CircularProgressIndicator] and the label is replaced with [busyLabel].
class AsyncIconActionButton extends StatelessWidget {
  final Future<void> Function() onPressed;
  final IconData idleIcon;
  final String idleLabel;
  final String busyLabel;

  const AsyncIconActionButton({
    required this.onPressed,
    required this.idleIcon,
    required this.idleLabel,
    required this.busyLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) => TapDebouncer(
    onTap: onPressed,
    cooldown: Duration.zero,
    builder: (context, onTap) => ElevatedButton.icon(
      onPressed: onTap,
      icon: onTap == null
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(idleIcon),
      label: Text(onTap == null ? busyLabel : idleLabel),
    ),
  );
}
