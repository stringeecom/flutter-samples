import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../call/stringee_call_model.dart';
import '../common/common.dart';

abstract class StringeeCallManagerInterface {
  /// Handle incoming call
  /// required [call] or [call2]
  Future<Result> handleIncomingCall({StringeeCall? call, StringeeCall2? call2});

  /// Handle outgoing call
  Future<Result> handleOutgoingCall({
    required String from,
    required String to,
    StringeeCall? call,
    StringeeCall2? call2,
    Map<dynamic, dynamic>? customData,
    VideoQuality? videoQuality,
  });

  /// handle with call
  // call this when user made a call to handle callkit or something else
  Future<Result> madeCall(StringeeCallModel call);
  // call this when user answered a call to handle callkit or something else
  Future<Result> answeredCall(StringeeCallModel call);
  // call this when a call has ended to handle callkit or something else
  Future<Result> endedCall(StringeeCallModel call);
}
