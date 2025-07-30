import 'package:call_sample/stringee_wrapper/widgets/call_action_widget.dart';
import 'package:flutter/material.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

class CallButtonAudio extends StatelessWidget {
  final Function() onPressed;
  final AudioDevice audioDevice;

  const CallButtonAudio(
      {super.key, required this.onPressed, required this.audioDevice});

  @override
  Widget build(BuildContext context) {
    IconData? icon = Icons.volume_down;
    Color? color = Colors.black;
    Color? primary = Colors.white;
    if (audioDevice.audioType == AudioType.speakerPhone) {
      icon = Icons.volume_up;
      color = Colors.white;
      primary = Colors.white54;
    } else if (audioDevice.audioType == AudioType.wiredHeadset) {
      icon = Icons.headphones;
      color = Colors.black;
      primary = Colors.white;
    } else if (audioDevice.audioType == AudioType.earpiece) {
      icon = Icons.volume_down;
      color = Colors.black;
      primary = Colors.white;
    } else if (audioDevice.audioType == AudioType.bluetooth) {
      icon = Icons.bluetooth;
      color = Colors.black;
      primary = Colors.white;
    }
    return CallActionWidget(
      onPressed: onPressed,
      icon: icon,
      color: color,
      backgroundColor: primary,
    );
  }
}
