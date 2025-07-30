import 'package:call_sample/stringee_wrapper/widgets/call_action_widget.dart';
import 'package:flutter/material.dart';

class CallButtonSwitch extends StatelessWidget {
  final Function() onPressed;

  const CallButtonSwitch({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return CallActionWidget(
      onPressed: onPressed,
      icon: Icons.flip_camera_ios_rounded,
    );
  }
}
