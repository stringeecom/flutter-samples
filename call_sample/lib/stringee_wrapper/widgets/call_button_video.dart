import 'package:call_sample/stringee_wrapper/widgets/call_action_widget.dart';
import 'package:flutter/material.dart';

class CallButtonVideo extends StatelessWidget {
  final Function() onPressed;
  final bool enabled;

  const CallButtonVideo(
      {super.key, required this.onPressed, required this.enabled});

  @override
  Widget build(BuildContext context) {
    IconData icon = enabled ? Icons.videocam_rounded : Icons.videocam_off_rounded;
    Color color = enabled ? Colors.white : Colors.black;
    Color backgroundColor = enabled ? Colors.white54 : Colors.white;
    return CallActionWidget(
      onPressed: onPressed,
      icon: icon,
      color: color,
      backgroundColor: backgroundColor,
    );
  }
}
