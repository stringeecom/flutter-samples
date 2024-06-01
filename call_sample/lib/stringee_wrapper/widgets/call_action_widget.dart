import 'package:flutter/material.dart';

class CallActionWidget extends StatelessWidget {
  final String iconPath;
  final Function() onPressed;
  final double width;
  final double height;

  const CallActionWidget({
    super.key,
    required this.iconPath,
    required this.onPressed,
    this.width = 70,
    this.height = 70,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Image.asset(
        iconPath,
        width: width,
        height: height,
      ),
    );
  }
}
