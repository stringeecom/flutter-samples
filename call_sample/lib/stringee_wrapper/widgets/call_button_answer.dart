import 'package:call_sample/stringee_wrapper/widgets/call_action_widget.dart';
import 'package:flutter/material.dart';

class CallButtonAnswer extends StatelessWidget {
  final Function() onPressed;

  const CallButtonAnswer({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return CallActionWidget(
      onPressed: onPressed,
      icon: Icons.call_rounded,
      backgroundColor: Colors.green.shade600,
      size: 32,
    );
  }
}
