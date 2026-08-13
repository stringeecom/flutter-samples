import 'package:flutter/material.dart';

/// Layout that gives call content three quarters and actions one quarter.
class SCCallingWidget extends StatelessWidget {
  /// Main call status or media content.
  final Widget body;

  /// Bottom call-control content.
  final Widget bottom;

  /// Creates the shared call-screen layout.
  const SCCallingWidget({
    super.key,
    required this.body,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(flex: 3, child: body),
          Expanded(flex: 1, child: bottom)
        ],
      ),
    );
  }
}
