import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import 'stringee_wrapper.dart';

class CallWrapper {
  late ReceivePort _receivePort;

  CallWrapper._privateConstructor() {
    _receivePort = ReceivePort();
    _receivePort.listen((message) {
      debugPrint('receivePort: $message');
      if (message == getCallId() && _callStatus != CallStatus.ended) {
        _callStatus = CallStatus.ended;
        release();
        if (_callListener != null) {
          _callListener!.onCallStatus(_callStatus);
        }
      }
    });
    IsolateNameServer.registerPortWithName(
        _receivePort.sendPort, endCallFromPushServerName);
  }

  static CallWrapper? _instance;

  factory CallWrapper() {
    _instance ??= CallWrapper._privateConstructor();
    return _instance!;
  }

  StringeeCall? _stringeeCall;
  StringeeCall2? _stringeeCall2;
  CallListener? _callListener;
  late StringeeSignalingState _signalingState = StringeeSignalingState.calling;
  late StringeeMediaState _mediaState = StringeeMediaState.disconnected;
  CallStatus _callStatus = CallStatus.calling;
  late String _userId;
  late bool _isVideoCall = false;
  late bool _isSpeakerOn = false;
  late bool _isVideoEnable = false;
  bool _isMicOn = true;

  CallStatus get callStatus => _callStatus;

  bool get isVideoCall => _isVideoCall;

  bool get isSpeakerOn => _isSpeakerOn;

  bool get isVideoEnable => _isVideoEnable;

  bool get isMicOn => _isMicOn;

  StringeeCall? get stringeeCall => _stringeeCall;

  StringeeCall2? get stringeeCall2 => _stringeeCall2;

  CallListener? get callListener => _callListener;

  String callee() {
    if (_stringeeCall != null) {
      return _stringeeCall!.from!;
    } else if (_stringeeCall2 != null) {
      return _stringeeCall2!.from!;
    } else {
      return '';
    }
  }

  void registerEvent(CallListener callListener) {
    _callListener = callListener;
  }

  void handleOnChangeSignalingState(StringeeSignalingState signalingState) {
    debugPrint('onChangeSignalingState: signalingState - $signalingState');
    _signalingState = signalingState;
    switch (_signalingState) {
      case StringeeSignalingState.calling:
        _callStatus = CallStatus.calling;
        break;
      case StringeeSignalingState.ringing:
        _callStatus = CallStatus.ringing;
        break;
      case StringeeSignalingState.answered:
        _callStatus = CallStatus.starting;
        if (_mediaState == StringeeMediaState.connected) {
          _callStatus = CallStatus.started;
        }
        break;
      case StringeeSignalingState.busy:
        _callStatus = CallStatus.busy;
        release();
        break;
      case StringeeSignalingState.ended:
        _callStatus = CallStatus.ended;
        release();
        break;
    }
    if (_callListener != null) {
      _callListener!.onCallStatus(_callStatus);
    }
    if (StringeeWrapper().listener != null) {
      StringeeWrapper().listener!.onCallSignalingStateChange(signalingState);
    }
  }

  void handleOnChangeMediaState(StringeeMediaState mediaState) {
    debugPrint('onChangeMediaState: mediaState - $mediaState');
    _mediaState = mediaState;
    switch (_mediaState) {
      case StringeeMediaState.connected:
        if (_signalingState == StringeeSignalingState.answered) {
          _callStatus = CallStatus.started;
          if (_callListener != null) {
            _callListener!.onCallStatus(_callStatus);
          }
        }
        break;
      case StringeeMediaState.disconnected:
        break;
    }
    if (StringeeWrapper().listener != null) {
      StringeeWrapper().listener!.onCallMediaStateChane(mediaState);
    }
  }

  void handleOnReceiveCallInfo(Map<dynamic, dynamic> callInfo) {
    debugPrint('onReceiveCallInfo: callInfo - $callInfo');
  }

  void handleOnHandleOnAnotherDevice(StringeeSignalingState signalingState) {
    debugPrint('onHandleOnAnotherDevice: signalingState - $signalingState');
    if (signalingState != StringeeSignalingState.ringing) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
    }
  }

  void handleOnReceiveLocalStream() {
    debugPrint('onReceiveLocalStream: onReceiveLocalStream');
    if (_callListener != null) {
      _callListener!.onReceiveLocalStream();
    }
  }

  void handleOnReceiveRemoteStream() {
    debugPrint('onReceiveRemoteStream: onReceiveRemoteStream');
    if (_callListener != null) {
      _callListener!.onReceiveRemoteStream();
    }
  }

  void handleOnChangeAudioDevice(AudioDevice selectedAudioDevice,
      List<AudioDevice> availableAudioDevices) {
    debugPrint(
        'onChangeAudioDevice: selectedAudioDevice - $selectedAudioDevice - availableAudioDevices - $availableAudioDevices');
  }

  void makeCall(String from, String to, bool isVideoCall,
      CallBackListener callBackListener) async {
    isInCall = true;
    if (isVideoCall) {
      _stringeeCall2 = StringeeCall2(StringeeWrapper().stringeeClient!);
    } else {
      _stringeeCall = StringeeCall(StringeeWrapper().stringeeClient!);
    }

    _userId = to;
    _isVideoCall = isVideoCall;
    _isSpeakerOn = isVideoCall;
    _isVideoEnable = isVideoCall;
    registerCallEvent();
    if (await isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      if (callBackListener.onError != null) {
        callBackListener.onError!('call is not initialized');
      }
      release();
      return;
    }
    if (isVideoCall) {
      _stringeeCall2!
          .makeCallFromParams(
              MakeCallParams(from, _userId, isVideoCall: _isVideoCall))
          .then((value) => handleMakeCallResult(value, callBackListener));
    } else {
      _stringeeCall!
          .makeCallFromParams(
              MakeCallParams(from, _userId, isVideoCall: _isVideoCall))
          .then((value) => handleMakeCallResult(value, callBackListener));
    }
  }

  void handleMakeCallResult(
      Map<dynamic, dynamic> result, CallBackListener callBackListener) {
    debugPrint('makeCall: $result');
    if (result['status']) {
      if (callBackListener.onSuccess != null) {
        callBackListener.onSuccess!();
      }
      setUpSpeakerBeforeCall();
    } else {
      if (callBackListener.onError != null) {
        callBackListener.onError!(result['message']);
      }
      release();
    }
  }

  Future<void> initAnswer(CallBackListener callBackListener,
      {StringeeCall? stringeeCall, StringeeCall2? stringeeCall2}) async {
    if (Platform.isIOS) {
      CallkeepManager.shared
          ?.reportIncomingCallIfNeeded(
              stringeeCall != null, stringeeCall, stringeeCall2)
          .then((value) => null);
    }
    if (stringeeCall != null) {
      _stringeeCall = stringeeCall;
      _userId = stringeeCall.from!;
      _isVideoCall = stringeeCall.isVideoCall;
      _isSpeakerOn = stringeeCall.isVideoCall;
      _isVideoEnable = stringeeCall.isVideoCall;
      _stringeeCall!
          .initAnswer()
          .then((value) => handleInitAnswerResult(value, callBackListener));
      registerCallEvent();
    } else if (stringeeCall2 != null) {
      _stringeeCall2 = stringeeCall2;
      _userId = stringeeCall2.from!;
      _isVideoCall = stringeeCall2.isVideoCall;
      _isSpeakerOn = stringeeCall2.isVideoCall;
      _isVideoEnable = stringeeCall2.isVideoCall;
      _stringeeCall2!
          .initAnswer()
          .then((value) => handleInitAnswerResult(value, callBackListener));
      registerCallEvent();
    } else {
      callBackListener.onError!('Call is not initialized');
    }
  }

  void handleInitAnswerResult(
      Map<dynamic, dynamic> result, CallBackListener callBackListener) {
    debugPrint('initAnswer: $result');
    if (!result['status']) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      if (callBackListener.onError != null) {
        callBackListener.onError!(result['message']);
      }
      release();
    } else {
      if (callBackListener.onSuccess != null) {
        callBackListener.onSuccess!();
      }
      _callStatus = CallStatus.incoming;
    }
  }

  void registerCallEvent() {
    if (_stringeeCall != null) {
      _stringeeCall!.registerEvent(StringeeCallListener(
        onChangeSignalingState: handleOnChangeSignalingState,
        onChangeMediaState: handleOnChangeMediaState,
        onReceiveCallInfo: handleOnReceiveCallInfo,
        onHandleOnAnotherDevice: handleOnHandleOnAnotherDevice,
        onReceiveLocalStream: handleOnReceiveLocalStream,
        onReceiveRemoteStream: handleOnReceiveRemoteStream,
        onChangeAudioDevice: handleOnChangeAudioDevice,
      ));
    }
    if (_stringeeCall2 != null) {
      _stringeeCall2!.registerEvent(StringeeCall2Listener(
        onChangeSignalingState: handleOnChangeSignalingState,
        onChangeMediaState: handleOnChangeMediaState,
        onReceiveCallInfo: handleOnReceiveCallInfo,
        onHandleOnAnotherDevice: handleOnHandleOnAnotherDevice,
        onReceiveLocalStream: handleOnReceiveLocalStream,
        onReceiveRemoteStream: handleOnReceiveRemoteStream,
        onChangeAudioDevice: handleOnChangeAudioDevice,
      ));
    }
  }

  void answer() async {
    if (await isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }

    if (Platform.isIOS) {
      CallkeepManager.shared
          ?.answerCallKeepIfNeed(
              _stringeeCall != null, _stringeeCall, _stringeeCall2)
          .then((value) => {debugPrint('end call keep')});
    }

    if (_signalingState == StringeeSignalingState.calling ||
        _signalingState == StringeeSignalingState.ringing) {
      if (_stringeeCall != null) {
        _stringeeCall!.answer().then(handleAnswerResult);
      }
      if (_stringeeCall2 != null) {
        _stringeeCall2!.answer().then(handleAnswerResult);
      }
    }
  }

  void handleAnswerResult(Map<dynamic, dynamic> result) {
    debugPrint('answer: $result');
    if (!result['status']) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
    } else {
      setUpSpeakerBeforeCall();
      _signalingState = StringeeSignalingState.answered;
      _callStatus = CallStatus.starting;
      if (_mediaState == StringeeMediaState.connected) {
        _callStatus = CallStatus.started;
      }
    }
  }

  void handleEndCallFromPush() {
    if (_callListener != null) {
      _callListener!.onCallStatus(CallStatus.ended);
    }
    release();
  }

  void setUpSpeakerBeforeCall() async {
    if (await isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_stringeeCall != null) {
      _stringeeCall!.setSpeakerphoneOn(_isSpeakerOn).then(
        (result) {
          debugPrint('setSpeakerphoneOn: $result');
        },
      );
    }
    if (_stringeeCall2 != null) {
      _stringeeCall2!.setSpeakerphoneOn(_isSpeakerOn).then(
        (result) {
          debugPrint('setSpeakerphoneOn: $result');
        },
      );
    }
  }

  void endCall(bool isHangUp) async {
    if (await isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }

    if (Platform.isIOS) {
      CallkeepManager.shared
          ?.endCallKeepIfNeed(
              _stringeeCall != null, _stringeeCall, _stringeeCall2)
          .then((value) => {debugPrint('end call keep')});
    }

    if (_stringeeCall != null) {
      if (isHangUp) {
        _stringeeCall!.hangup().then(handleHangUpResult);
      } else {
        _stringeeCall!.reject().then(handleRejectResult);
      }
    }
    if (_stringeeCall2 != null) {
      if (isHangUp) {
        _stringeeCall2!.hangup().then(handleHangUpResult);
      } else {
        _stringeeCall2!.reject().then(handleRejectResult);
      }
    }
    if (_callListener != null) {
      _callListener!.onCallStatus(CallStatus.ended);
    }
    release();
  }

  void handleHangUpResult(Map<dynamic, dynamic> result) {
    debugPrint('hangup: $result');
  }

  void handleRejectResult(Map<dynamic, dynamic> result) {
    debugPrint('reject: $result');
  }

  void enableVideo() async {
    if (await isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_stringeeCall != null) {
      _stringeeCall!.enableVideo(!_isVideoEnable).then(handleEnableVideoResult);
    }
    if (_stringeeCall2 != null) {
      _stringeeCall2!
          .enableVideo(!_isVideoEnable)
          .then(handleEnableVideoResult);
    }
  }

  void handleEnableVideoResult(Map<dynamic, dynamic> result) {
    debugPrint('enableVideo: $result');
    if (result['status']) {
      _isVideoEnable = !_isVideoEnable;
      if (_callListener != null) {
        _callListener!.onVideoChange(_isVideoEnable);
      }
    }
  }

  void mute() async {
    if (await isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_stringeeCall != null) {
      _stringeeCall!.mute(_isMicOn).then(handleMuteResult);
    }
    if (_stringeeCall2 != null) {
      _stringeeCall2!.mute(_isMicOn).then(handleMuteResult);
    }
  }

  void handleMuteResult(Map<dynamic, dynamic> result) {
    debugPrint('mute: $result');
    if (result['status']) {
      _isMicOn = !_isMicOn;
      if (_callListener != null) {
        _callListener!.onMicChange(_isMicOn);
      }
    }
  }

  void changeSpeaker() async {
    if (await isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_stringeeCall != null) {
      _stringeeCall!
          .setSpeakerphoneOn(!_isSpeakerOn)
          .then(handleChangeSpeakerResult);
    }
    if (_stringeeCall2 != null) {
      _stringeeCall2!
          .setSpeakerphoneOn(!_isSpeakerOn)
          .then(handleChangeSpeakerResult);
    }
  }

  void handleChangeSpeakerResult(Map<dynamic, dynamic> result) {
    debugPrint('setSpeakerphoneOn: $result');
    if (result['status']) {
      _isSpeakerOn = !_isSpeakerOn;
      if (_callListener != null) {
        _callListener!.onSpeakerChange(_isSpeakerOn);
      }
    }
  }

  void switchCamera() async {
    if (await isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_stringeeCall != null) {
      _stringeeCall!.switchCamera().then(handleSwitchCameraResult);
    }
    if (_stringeeCall2 != null) {
      _stringeeCall2!.switchCamera().then(handleSwitchCameraResult);
    }
  }

  void handleSwitchCameraResult(Map<dynamic, dynamic> result) {
    debugPrint('switchCamera: $result');
  }

  void release() {
    debugPrint('release callManager');
    if (Platform.isIOS) {
      CallkeepManager.shared
          ?.endCallKeepIfNeed(
              _stringeeCall != null, _stringeeCall, _stringeeCall2)
          .then((value) => {debugPrint('end call keep')});
    }
    isInCall = false;
    if (_stringeeCall != null) {
      if (_stringeeCall != null) {
        _stringeeCall!.destroy();
      }
      _stringeeCall = null;
    }
    if (_stringeeCall2 != null) {
      if (_stringeeCall2 != null) {
        _stringeeCall2!.destroy();
      }
      _stringeeCall2 = null;
    }
    CallWrapper._instance = null;
    StringeeWrapper().callWidget = null;
  }

  Future<bool> isCallNotInitialized() async {
    bool isCallNotInitialized = true;
    if (_stringeeCall != null) {
      isCallNotInitialized = _stringeeCall == null;
    } else if (_stringeeCall2 != null) {
      isCallNotInitialized = _stringeeCall2 == null;
    }
    return isCallNotInitialized;
  }

  String getCallId() {
    String callId = '';
    if (_stringeeCall != null) {
      callId = _stringeeCall!.id!;
    } else if (_stringeeCall2 != null) {
      callId = _stringeeCall2!.id!;
    }
    return callId;
  }

  String getFrom() {
    String from = '';
    if (_stringeeCall != null) {
      from = _stringeeCall!.from!;
    } else if (_stringeeCall2 != null) {
      from = _stringeeCall2!.from!;
    }
    return from;
  }

  (String, int)? currentCallIdAndSerial() {
    if (_stringeeCall != null) {
      if (_stringeeCall == null) {
        return null;
      }
      return (_stringeeCall?.id ?? '', _stringeeCall?.serial ?? 1);
    } else if (_stringeeCall2 != null) {
      if (_stringeeCall2 == null) {
        return null;
      }
      return (_stringeeCall2?.id ?? '', _stringeeCall2?.serial ?? 1);
    }
    return null;
  }
}
