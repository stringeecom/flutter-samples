import 'package:call_sample/stringee_wrapper/widgets/call_action_widget.dart';
import 'package:flutter/material.dart';

/// Control that toggles microphone transmission.
class CallButtonMic extends StatelessWidget {
  /// Callback invoked when the microphone control is pressed.
  final Function() onPressed;

  /// Whether microphone transmission is currently enabled.
  final bool enabled;

  /// Creates a microphone control.
  const CallButtonMic(
      {super.key, required this.onPressed, required this.enabled});

  @override
  Widget build(BuildContext context) {
    IconData icon = enabled ? Icons.mic_rounded : Icons.mic_off_rounded;
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
