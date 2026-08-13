import 'package:call_sample/stringee_wrapper/widgets/call_action_widget.dart';
import 'package:flutter/material.dart';

/// Control that switches between available cameras.
class CallButtonSwitch extends StatelessWidget {
  /// Callback invoked when the camera-switch control is pressed.
  final Function() onPressed;

  /// Creates a camera-switch control.
  const CallButtonSwitch({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return CallActionWidget(
      onPressed: onPressed,
      icon: Icons.flip_camera_ios_rounded,
    );
  }
}
