import 'package:flutter/material.dart';

// 3/4 view to display calling screen
// 1/4 view to display call actions
class SCCallingWidget extends StatelessWidget {
  final Widget body;
  final Widget bottom;

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
