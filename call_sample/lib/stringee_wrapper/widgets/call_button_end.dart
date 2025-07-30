import 'package:call_sample/stringee_wrapper/widgets/call_action_widget.dart';
import 'package:flutter/material.dart';

class CallButtonEnd extends StatelessWidget {
  final Function() onPressed;

  const CallButtonEnd({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return CallActionWidget(
      onPressed: onPressed,
      icon: Icons.call_end_rounded,
      backgroundColor: Colors.red.shade600,
      size: 32,
    );
  }
}
