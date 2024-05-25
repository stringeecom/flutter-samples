import 'package:flutter/material.dart';

class StringeeAvatarWidget extends StatelessWidget {
  final Color backgroundColor;
  final String? text;
  const StringeeAvatarWidget({
    super.key,
    this.backgroundColor = const Color.fromRGBO(64, 182, 73, 1.0),
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.white,
      child: CircleAvatar(
        radius: 57,
        backgroundColor: backgroundColor,
        child: Text(
          text != null && text!.isNotEmpty
              ? text!.characters.first.toUpperCase()
              : '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 50.0,
          ),
        ),
      ),
    );
  }
}
