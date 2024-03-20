import 'package:flutter/material.dart';

class MainButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final EdgeInsetsGeometry? margin;

  const MainButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40.0,
      width: 175.0,
      margin: margin,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }
}
