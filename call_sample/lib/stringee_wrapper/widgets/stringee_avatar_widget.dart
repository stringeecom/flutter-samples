import 'package:flutter/material.dart';

/// Circular fallback avatar derived from the remote party identifier.
class StringeeAvatarWidget extends StatelessWidget {
  /// Fill color behind the initial.
  final Color backgroundColor;

  /// Text whose first character is displayed as the avatar initial.
  final String? text;

  /// Creates a fallback call avatar.
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
