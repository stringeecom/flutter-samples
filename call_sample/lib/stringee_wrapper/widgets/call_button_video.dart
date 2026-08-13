import 'package:call_sample/stringee_wrapper/widgets/call_action_widget.dart';
import 'package:flutter/material.dart';

/// Control that toggles camera transmission.
class CallButtonVideo extends StatelessWidget {
  /// Callback invoked when the video control is pressed.
  final Function() onPressed;

  /// Whether camera transmission is currently enabled.
  final bool enabled;

  /// Creates a video control.
  const CallButtonVideo(
      {super.key, required this.onPressed, required this.enabled});

  @override
  Widget build(BuildContext context) {
    IconData icon =
        enabled ? Icons.videocam_rounded : Icons.videocam_off_rounded;
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
