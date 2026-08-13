import 'package:call_sample/stringee_wrapper/widgets/call_action_widget.dart';
import 'package:flutter/material.dart';

/// Red control used to reject or end a call.
class CallButtonEnd extends StatelessWidget {
  /// Callback invoked when the control is pressed.
  final Function() onPressed;

  /// Creates an end-call control.
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
