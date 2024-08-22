import 'dart:async';

import 'package:stringee_plugin/stringee_plugin.dart';

abstract class StringeeCallInterface {
  String? get callId;

  int? get serial;

  String? get from;

  String? get to;

  String? get fromAlias;

  String? get toAlias;

  // bool get isIncomingCall;
  StringeeCallType? get callType;

  String? get customDataFromYourServer;

  bool get isVideoCall;

  StreamController<dynamic> get eventStreamController;

  // SignalingState get signalingState;
  // bool get answeredOnAnotherDevice;
  // VideoResolution get videoResolution;
  // bool get peerToPeerCall;

  Future<Map<dynamic, dynamic>> makeCall(Map<dynamic, dynamic> parameters);

  Future<Map<dynamic, dynamic>> makeCallFromParams(MakeCallParams params);

  Future<Map<dynamic, dynamic>> initAnswer();

  Future<Map<dynamic, dynamic>> answer();

  Future<Map<dynamic, dynamic>> reject();

  Future<Map<dynamic, dynamic>> hangup();

  Future<Map<dynamic, dynamic>> send(String dtmf);

  Future<Map<dynamic, dynamic>> sendCallInfo(Map<dynamic, dynamic> callInfo);

  Future<Map<dynamic, dynamic>> getCallStats();

  Future<Map<dynamic, dynamic>> mute(bool mute);

  Future<Map<dynamic, dynamic>> enableVideo(bool enableVideo);

  Future<Map<dynamic, dynamic>> setSpeakerphoneOn(bool speakerPhoneOn);

  Future<Map<dynamic, dynamic>> switchCamera({String? cameraId});

  Future<Map<dynamic, dynamic>> resumeVideo();

  Future<Map<dynamic, dynamic>> setMirror(bool isLocal, bool isMirror);
}

class StringeeCallWrapper implements StringeeCallInterface {
  final StringeeCall _call;

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
  Future<Map> setSpeakerphoneOn(bool speakerPhoneOn) {
    return _call.setSpeakerphoneOn(speakerPhoneOn);
  }

  @override
  Future<Map> switchCamera({String? cameraId}) {
    return _call.switchCamera(cameraId: cameraId);
  }
}

class StringeeCall2Wrapper implements StringeeCallInterface {
  final StringeeCall2 _call;

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
  Future<Map> setSpeakerphoneOn(bool speakerPhoneOn) {
    return _call.setSpeakerphoneOn(speakerPhoneOn);
  }

  @override
  Future<Map> switchCamera({String? cameraId}) {
    return _call.switchCamera(cameraId: cameraId);
  }
}
