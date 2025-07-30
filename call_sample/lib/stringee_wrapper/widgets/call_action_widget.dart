import 'package:flutter/material.dart';

class CallActionWidget extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final Function() onPressed;
  final double size;

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
