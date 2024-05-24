import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../stringee_listener.dart';

abstract class StringeeWrapperInterface {
  // client methods

  /// connect to Stringee server
  /// [token] is the token of the user
  Future<void> connect(String token);

  /// disconnect from Stringee server
  Future<void> disconnect();

  /// enable/unregister push to receive call when app is in background
  Future<void> enablePush();
  Future<void> unregisterPush();

  // call methods

  /// make a call
  /// [from] is the caller id
  /// [to] is the callee id
  /// [isVideoCall] is the type of the call
  /// if [isVideoCall] is true, the call is a video call
  /// if [isVideoCall] is false, the call is an audio call
  /// [isVideoCall] default is false
  Future<void> makeCall({
    required String from,
    required String to,
    bool isVideoCall = false,
    Map<dynamic, dynamic>? customData,
    VideoQuality? videoQuality,
  });

  // listener methods

  /// add a listener to listen to Stringee events
  Future<void> addListener(StringeeListener listener);
}
