import 'dart:io';

import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

export 'result.dart';

bool get isIOS => Platform.isIOS;

extension StringeeSignalingStateX on StringeeSignalingState {
  bool get isCalling => this == StringeeSignalingState.calling;
  bool get isRinging => this == StringeeSignalingState.ringing;
  bool get isAnswered => this == StringeeSignalingState.answered;
  bool get isBusy => this == StringeeSignalingState.busy;
  bool get isEnded => this == StringeeSignalingState.ended;
}
