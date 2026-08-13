import 'dart:async';

import 'package:stringee_plugin/stringee_plugin.dart';

/// Common operations used by the sample for `StringeeCall` and `StringeeCall2`.
///
/// This abstraction keeps call state, UI, timeout, and notification handling
/// independent from the selected Stringee call generation.
abstract class StringeeCallInterface {
  /// Server-assigned call identifier.
  String? get callId;

  /// SDK serial number for this call instance.
  int? get serial;

  /// Caller identifier.
  String? get from;

  /// Callee identifier.
  String? get to;

  /// Display alias of the caller.
  String? get fromAlias;

  /// Display alias of the callee.
  String? get toAlias;

  // bool get isIncomingCall;
  /// Direction and endpoint type reported by the SDK.
  StringeeCallType? get callType;

  /// Custom data returned by the application server.
  String? get customDataFromYourServer;

  /// Whether this call negotiates video.
  bool get isVideoCall;

  /// Stream of call-specific SDK events.
  StreamController<dynamic> get eventStreamController;

  // SignalingState get signalingState;
  // bool get answeredOnAnotherDevice;
  // VideoResolution get videoResolution;
  // bool get peerToPeerCall;

  /// Starts an outgoing call from a legacy parameter map.
  Future<Map<dynamic, dynamic>> makeCall(Map<dynamic, dynamic> parameters);

  /// Starts an outgoing call from typed [params].
  Future<Map<dynamic, dynamic>> makeCallFromParams(MakeCallParams params);

  /// Initializes native resources for an incoming call before answering.
  Future<Map<dynamic, dynamic>> initAnswer();

  /// Answers an initialized incoming call.
  Future<Map<dynamic, dynamic>> answer();

  /// Rejects an unanswered incoming call.
  Future<Map<dynamic, dynamic>> reject();

  /// Hangs up an active or outgoing call.
  Future<Map<dynamic, dynamic>> hangup();

  /// Sends one DTMF [dtmf] value.
  Future<Map<dynamic, dynamic>> send(String dtmf);

  /// Sends application [callInfo] through the active call.
  Future<Map<dynamic, dynamic>> sendCallInfo(Map<dynamic, dynamic> callInfo);

  /// Returns current SDK call statistics.
  Future<Map<dynamic, dynamic>> getCallStats();

  /// Enables or disables microphone transmission.
  Future<Map<dynamic, dynamic>> mute(bool mute);

  /// Enables or disables camera transmission.
  Future<Map<dynamic, dynamic>> enableVideo(bool enableVideo);

  /// Selects the active [device] through the shared audio manager.
  Future<Result> changeAudioDevice(AudioDevice device);

  /// Switches to [cameraId], or toggles camera when it is omitted.
  Future<Map<dynamic, dynamic>> switchCamera({String? cameraId});

  /// Resumes video after an interruption supported by the SDK.
  Future<Map<dynamic, dynamic>> resumeVideo();

  /// Sets mirroring for the local or remote renderer.
  Future<Map<dynamic, dynamic>> setMirror(bool isLocal, bool isMirror);
}

/// Adapts a first-generation [StringeeCall] to [StringeeCallInterface].
class StringeeCallWrapper implements StringeeCallInterface {
  final StringeeCall _call;

  /// Creates an adapter around [_call].
  StringeeCallWrapper(this._call);

  @override
  String? get callId => _call.id;

  @override
  int? get serial => _call.serial;

  @override
  StringeeCallType? get callType => _call.callType;

  @override
  bool get isVideoCall => _call.isVideoCall;

  @override
  String? get customDataFromYourServer => _call.customDataFromYourServer;

  @override
  StreamController get eventStreamController => _call.eventStreamController;

  @override
  String? get from => _call.from;

  @override
  String? get fromAlias => _call.fromAlias;

  @override
  String? get to => _call.to;

  @override
  String? get toAlias => _call.toAlias;

  @override
  Future<Map> getCallStats() {
    return _call.getCallStats();
  }

  @override
  Future<Map> answer() async {
    return _call.answer();
  }

  @override
  Future<Map> hangup() {
    return _call.hangup();
  }

  @override
  Future<Map> initAnswer() {
    return _call.initAnswer();
  }

  @override
  Future<Map> makeCall(Map parameters) {
    return _call.makeCall(parameters);
  }

  @override
  Future<Map> makeCallFromParams(MakeCallParams params) {
    return _call.makeCallFromParams(params);
  }

  @override
  Future<Map> mute(bool mute) {
    return _call.mute(mute);
  }

  @override
  Future<Map> reject() {
    return _call.reject();
  }

  @override
  Future<Map> resumeVideo() {
    return _call.resumeVideo();
  }

  @override
  Future<Map> send(String dtmf) {
    return _call.sendDtmf(dtmf);
  }

  @override
  Future<Map> sendCallInfo(Map callInfo) {
    return _call.sendCallInfo(callInfo);
  }

  @override
  Future<Map> setMirror(bool isLocal, bool isMirror) {
    return _call.setMirror(isLocal, isMirror);
  }

  @override
  Future<Map> enableVideo(bool enableVideo) {
    return _call.enableVideo(enableVideo);
  }

  @override
  Future<Result> changeAudioDevice(AudioDevice device) {
    return StringeeAudioManager().selectDevice(device);
  }

  @override
  Future<Map> switchCamera({String? cameraId}) {
    return _call.switchCamera(cameraId: cameraId);
  }
}

/// Adapts a second-generation [StringeeCall2] to [StringeeCallInterface].
class StringeeCall2Wrapper implements StringeeCallInterface {
  final StringeeCall2 _call;

  /// Creates an adapter around [_call].
  StringeeCall2Wrapper(this._call);

  @override
  String? get callId => _call.id;

  @override
  int? get serial => _call.serial;

  @override
  StringeeCallType? get callType => _call.callType;

  @override
  bool get isVideoCall => _call.isVideoCall;

  @override
  String? get customDataFromYourServer => _call.customDataFromYourServer;

  @override
  StreamController get eventStreamController => _call.eventStreamController;

  @override
  String? get from => _call.from;

  @override
  String? get fromAlias => _call.fromAlias;

  @override
  String? get to => _call.to;

  @override
  String? get toAlias => _call.toAlias;

  @override
  Future<Map> getCallStats() {
    return _call.getCallStats();
  }

  @override
  Future<Map> answer() async {
    return _call.answer();
  }

  @override
  Future<Map> hangup() {
    return _call.hangup();
  }

  @override
  Future<Map> initAnswer() {
    return _call.initAnswer();
  }

  @override
  Future<Map> makeCall(Map parameters) {
    return _call.makeCall(parameters);
  }

  @override
  Future<Map> makeCallFromParams(MakeCallParams params) {
    return _call.makeCallFromParams(params);
  }

  @override
  Future<Map> mute(bool mute) {
    return _call.mute(mute);
  }

  @override
  Future<Map> reject() {
    return _call.reject();
  }

  @override
  Future<Map> resumeVideo() {
    return _call.resumeVideo();
  }

  @override
  Future<Map> send(String dtmf) {
    return _call.sendDtmf(dtmf);
  }

  @override
  Future<Map> sendCallInfo(Map callInfo) {
    return _call.sendCallInfo(callInfo);
  }

  @override
  Future<Map> setMirror(bool isLocal, bool isMirror) {
    return _call.setMirror(isLocal, isMirror);
  }

  @override
  Future<Map> enableVideo(bool enableVideo) {
    return _call.enableVideo(enableVideo);
  }

  @override
  Future<Result> changeAudioDevice(AudioDevice device) {
    return StringeeAudioManager().selectDevice(device);
  }

  @override
  Future<Map> switchCamera({String? cameraId}) {
    return _call.switchCamera(cameraId: cameraId);
  }
}
