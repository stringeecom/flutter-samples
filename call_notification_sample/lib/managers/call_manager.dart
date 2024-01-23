import 'package:flutter/material.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../listener/call_listener.dart';
import 'client_manager.dart';

class CallManager {
  CallManager._privateConstructor();

  static CallManager? _instance;

  factory CallManager() {
    _instance ??= CallManager._privateConstructor();
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
  bool _isStringeeCall = true;

  CallStatus get callStatus => _callStatus;

  bool get isVideoCall => _isVideoCall;

  bool get isSpeakerOn => _isSpeakerOn;

  bool get isVideoEnable => _isVideoEnable;

  bool get isMicOn => _isMicOn;

  StringeeCall? get stringeeCall => _stringeeCall;

  StringeeCall2? get stringeeCall2 => _stringeeCall2;

  bool get isStringeeCall => _isStringeeCall;

  void initializedOutgoingCall(
      String to, bool isVideoCall, bool isStringeeCall) {
    ClientManager().isInCall = true;
    if (isStringeeCall) {
      _stringeeCall = StringeeCall(ClientManager().stringeeClient!);
    } else {
      _stringeeCall2 = StringeeCall2(ClientManager().stringeeClient!);
    }
    _isStringeeCall = isStringeeCall;
    _userId = to;
    _isVideoCall = isVideoCall;
    _isSpeakerOn = isVideoCall;
    _isVideoEnable = isVideoCall;
    registerCallEvent();
  }

  void initializedIncomingCall(
    bool isStringeeCall, {
    StringeeCall? stringeeCall,
    StringeeCall2? stringeeCall2,
  }) {
    ClientManager().isInCall = true;
    _isStringeeCall = isStringeeCall;
    if (_isStringeeCall) {
      _stringeeCall = stringeeCall;
      _userId = stringeeCall!.from!;
    } else {
      _stringeeCall2 = stringeeCall2;
      _userId = stringeeCall2!.from!;
    }
    _isVideoCall = _isStringeeCall
        ? stringeeCall!.isVideoCall
        : stringeeCall2!.isVideoCall;
    _isSpeakerOn = _isStringeeCall
        ? stringeeCall!.isVideoCall
        : stringeeCall2!.isVideoCall;
    _isVideoEnable = _isStringeeCall
        ? stringeeCall!.isVideoCall
        : stringeeCall2!.isVideoCall;
    _callStatus = CallStatus.incoming;
    registerCallEvent();
  }

  void registerEvent(CallListener callListener) {
    _callListener = callListener;
  }

  void registerCallEvent() {
    if (_isStringeeCall) {
      _stringeeCall!.registerEvent(StringeeCallListener(
        onChangeSignalingState: handleOnChangeSignalingState,
        onChangeMediaState: handleOnChangeMediaState,
        onReceiveCallInfo: handleOnReceiveCallInfo,
        onHandleOnAnotherDevice: handleOnHandleOnAnotherDevice,
        onReceiveLocalStream: handleOnReceiveLocalStream,
        onReceiveRemoteStream: handleOnReceiveRemoteStream,
        onChangeAudioDevice: handleOnChangeAudioDevice,
      ));
    } else {
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

  void makeCall() {
    if (isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_isStringeeCall) {
      _stringeeCall!
          .makeCallFromParams(MakeCallParams(
              ClientManager().stringeeClient!.userId!, _userId,
              isVideoCall: _isVideoCall))
          .then(handleMakeCallResult);
    } else {
      _stringeeCall2!
          .makeCallFromParams(MakeCallParams(
              ClientManager().stringeeClient!.userId!, _userId,
              isVideoCall: _isVideoCall))
          .then(handleMakeCallResult);
    }
  }

  void handleMakeCallResult(Map<dynamic, dynamic> result) {
    debugPrint('makeCall: $result');
    if (!result['status']) {
      if (_callListener != null) {
        _callListener!.onError(result['message']);
      }
      release();
    } else {
      setUpSpeakerBeforeCall();
    }
  }

  void initAnswer() {
    if (isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_isStringeeCall) {
      _stringeeCall!.initAnswer().then(handleInitAnswerResult);
    } else {
      _stringeeCall2!.initAnswer().then(handleInitAnswerResult);
    }
  }

  void handleInitAnswerResult(Map<dynamic, dynamic> result) {
    debugPrint('initAnswer: $result');
    if (!result['status']) {
      if (_callListener != null) {
        _callListener!.onError(result['message']);
      }
      release();
    }
  }

  void answer() {
    if (isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_isStringeeCall) {
      _stringeeCall!.answer().then(handleAnswerResult);
    } else {
      _stringeeCall2!.answer().then(handleAnswerResult);
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
      _signalingState = StringeeSignalingState.answered;
      _callStatus = CallStatus.starting;
      if (_mediaState == StringeeMediaState.connected) {
        _callStatus = CallStatus.started;
      }
    }
  }

  void setUpSpeakerBeforeCall() {
    if (isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_isStringeeCall) {
      _stringeeCall!.setSpeakerphoneOn(_isSpeakerOn).then(
        (result) {
          debugPrint('setSpeakerphoneOn: $result');
        },
      );
    } else {
      _stringeeCall2!.setSpeakerphoneOn(_isSpeakerOn).then(
        (result) {
          debugPrint('setSpeakerphoneOn: $result');
        },
      );
    }
  }

  void endCall(bool isHangUp) {
    if (isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_isStringeeCall) {
      if (isHangUp) {
        _stringeeCall!.hangup().then(handleHangUpResult);
      } else {
        _stringeeCall!.reject().then(handleRejectResult);
      }
    } else {
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

  void enableVideo() {
    if (isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_isStringeeCall) {
      _stringeeCall!.enableVideo(!_isVideoEnable).then(handleEnableVideoResult);
    } else {
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

  void mute() {
    if (isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_isStringeeCall) {
      _stringeeCall!.mute(_isMicOn).then(handleMuteResult);
    } else {
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

  void changeSpeaker() {
    if (isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_isStringeeCall) {
      _stringeeCall!
          .setSpeakerphoneOn(!_isSpeakerOn)
          .then(handleChangeSpeakerResult);
    } else {
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

  void switchCamera() {
    if (isCallNotInitialized()) {
      if (_callListener != null) {
        _callListener!.onCallStatus(CallStatus.ended);
      }
      release();
      return;
    }
    if (_isStringeeCall) {
      _stringeeCall!.switchCamera().then(handleSwitchCameraResult);
    } else {
      _stringeeCall2!.switchCamera().then(handleSwitchCameraResult);
    }
  }

  void handleSwitchCameraResult(Map<dynamic, dynamic> result) {
    debugPrint('switchCamera: $result');
  }

  void release() {
    debugPrint('release callManager');
    ClientManager().isInCall = false;
    if (_isStringeeCall) {
      if (_stringeeCall != null) {
        _stringeeCall!.destroy();
      }
      _stringeeCall = null;
    } else {
      if (_stringeeCall2 != null) {
        _stringeeCall2!.destroy();
      }
      _stringeeCall2 = null;
    }
    CallManager._instance = null;
  }

  bool isCallNotInitialized() {
    bool isCallNotInitialized = true;
    if (_isStringeeCall) {
      isCallNotInitialized = _stringeeCall == null;
    } else {
      isCallNotInitialized = _stringeeCall2 == null;
    }
    if (isCallNotInitialized) {
      if (_callListener != null) {
        _callListener!.onError('call is not initialized');
      }
    }
    return isCallNotInitialized;
  }

  String getCallId() {
    String callId = '';
    if (_isStringeeCall) {
      if (stringeeCall != null) {
        callId = stringeeCall!.id!;
      }
    } else {
      if (stringeeCall2 != null) {
        callId = stringeeCall2!.id!;
      }
    }
    return callId;
  }

  String getFrom() {
    String from = '';
    if (_isStringeeCall) {
      if (stringeeCall != null) {
        from = stringeeCall!.from!;
      }
    } else {
      if (stringeeCall2 != null) {
        from = stringeeCall2!.from!;
      }
    }
    return from;
  }
}
