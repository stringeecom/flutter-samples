import 'package:flutter/material.dart';

/// Circular base button used by call control widgets.
class CallActionWidget extends StatelessWidget {
  /// Icon displayed in the button.
  final IconData icon;

  /// Icon color.
  final Color color;

  /// Circular button background color.
  final Color backgroundColor;

  /// Callback invoked when the control is pressed.
  final Function() onPressed;

  /// Requested icon size.
  final double size;

  /// Creates a circular call action.
  const CallActionWidget({
    super.key,
    required this.icon,
    this.color = Colors.white,
    this.backgroundColor = Colors.white54,
    required this.onPressed,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(14.0),
        backgroundColor: backgroundColor,
        shape: const CircleBorder(),
      ),
      child: Icon(
        icon,
        color: color,
        size: 28,
      ),
    );
  }
}
