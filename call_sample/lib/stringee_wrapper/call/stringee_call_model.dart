import 'dart:async';

import 'package:call_sample/stringee_wrapper/stringee_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../common/common.dart';
import '../interfaces/stringee_call_interface.dart';
import '../push_manager/callkeep_manager.dart';
import 'stringee_call_manager.dart';

class StringeeCallModel extends ChangeNotifier {
  /// intialize properties
  final StringeeCallInterface call;
  final bool isIncomingCall;
  final String? from;
  final String? to;
  final Map<dynamic, dynamic>? customData;
  final VideoQuality? videoQuality;

  /// call properties
  StringeeSignalingState _signalingState = StringeeSignalingState.calling;
  StringeeSignalingState get signalingState => _signalingState;
  StringeeMediaState _mediaState = StringeeMediaState.disconnected;
  StringeeMediaState get mediaState => _mediaState;
  // String _status = '';
  // String get status => _status;
  bool _isMute = false;
  bool get isMute => _isMute;
  bool _isVideoEnable = true;
  bool get isVideoEnable => _isVideoEnable;
  bool _isSpeaker = false;
  bool get isSpeaker => _isSpeaker;

  // TODO: - check if call is connected. need to check more
  bool get isInCall {
    if (mediaState == StringeeMediaState.connected) {
      return true;
    } else {
      return signalingState == StringeeSignalingState.answered;
    }
  }

  String _uuid = '';
  String get uuid => _uuid;

  void setUuid(String uuid) {
    _uuid = uuid;
  }

  /// check if call is a video call
  bool get isVideoCall {
    return call.isVideoCall;
    // return call is StringeeCall2Wrapper;
  }

  /// flag to check if local and remote stream is received
  bool _receivedLocalStream = false;
  bool _receivedRemoteStream = false;
  bool get readyLocalView => isVideoCall && _receivedLocalStream;
  bool get readyRemoteView => isVideoCall && _receivedRemoteStream;

  /// call timer && flag to check if timer is started
  Timer? _timer;
  bool _startedTimer = false;

  /// call time
  String _time = '00:00';
  String get time => _time;

  /// get callee
  String? get callee {
    return isIncomingCall ? call.from : call.to;
  }

  /// flags
  // flag to check if call is reported end call
  bool _reportedEndCall = false;
  // flag to check if call is reported answered call
  bool _reportedAnsweredCall = false;

  // flag to check if user answered call
  bool _isClickedAnswer = false;
  setIsClickedAnswer(bool value) {
    _isClickedAnswer = value;
  }

  /// check to end call by reject or hangup
  bool get isShouldReject => isIncomingCall && !_isClickedAnswer;

  StringeeCallModel(
    this.call, {
    this.isIncomingCall = true,
    this.from,
    this.to,
    this.customData,
    this.videoQuality,
  }) {
    call.eventStreamController.stream.listen((event) {
      debugPrint('$uuid StringeeCallModel ${call.callId} - event: $event');
      _handleStringeeCallEvent(event as Map<dynamic, dynamic>);
    });
    // make call if it is an outgoing call
    // if (!isIncomingCall) {
    //   makeCall();
    // }
  }

  _handleStringeeCallEvent(Map<dynamic, dynamic> event) async {
    switch (event['eventType']) {
      /// StringeeCallEvents
      case StringeeCallEvents.didChangeSignalingState:
        _handleSignalingStateChangeEvent(event['body']);
        break;
      case StringeeCallEvents.didChangeMediaState:
        _handleMediaStateChangeEvent(event['body']);
        break;
      case StringeeCallEvents.didReceiveCallInfo:
        _handleReceiveCallInfoEvent(event['body']);
        break;
      case StringeeCallEvents.didHandleOnAnotherDevice:
        _handleHandleOnAnotherDeviceEvent(event['body']);
        break;
      case StringeeCallEvents.didReceiveLocalStream:
        _handleReceiveLocalStreamEvent(event['body']);
        break;
      case StringeeCallEvents.didReceiveRemoteStream:
        _handleReceiveRemoteStreamEvent(event['body']);
        break;
      // This event only for android
      case StringeeCallEvents.didChangeAudioDevice:
        if (!isIOS) {
          _handleChangeAudioDeviceEvent(
              event['selectedAudioDevice'], event['availableAudioDevices']);
        }
        break;

      /// StringeeCall2Events
      case StringeeCall2Events.didChangeSignalingState:
        _handleSignalingStateChangeEvent(event['body']);
        break;
      case StringeeCall2Events.didChangeMediaState:
        _handleMediaStateChangeEvent(event['body']);
        break;
      case StringeeCall2Events.didReceiveCallInfo:
        _handleReceiveCallInfoEvent(event['body']);
        break;
      case StringeeCall2Events.didHandleOnAnotherDevice:
        _handleHandleOnAnotherDeviceEvent(event['body']);
        break;
      case StringeeCall2Events.didReceiveLocalStream:
        _handleReceiveLocalStreamEvent(event['body']);
        break;
      case StringeeCall2Events.didReceiveRemoteStream:
        _handleReceiveRemoteStreamEvent(event['body']);
        break;
      case StringeeCall2Events.didAddVideoTrack:
        _handleAddVideoTrackEvent(event['body']);
        break;
      case StringeeCall2Events.didRemoveVideoTrack:
        _handleRemoveVideoTrackEvent(event['body']);
        break;
      // This event only for android
      case StringeeCall2Events.didChangeAudioDevice:
        if (!isIOS) {
          _handleChangeAudioDeviceEvent(
              event['selectedAudioDevice'], event['availableAudioDevices']);
        }
        break;
    }
  }

  void _startCallTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      int second = timer.tick.toDouble().remainder(60).toInt();
      int minute = timer.tick.toDouble() ~/ 60;
      _time =
          '${minute < 10 ? '0$minute' : minute}:${second < 10 ? '0$second' : second}';
      notifyListeners();
    });
  }

  /// Invoked when get Signaling state
  void _handleSignalingStateChangeEvent(StringeeSignalingState state) {
    _signalingState = state;
    switch (state) {
      case StringeeSignalingState.calling:
        break;
      case StringeeSignalingState.ringing:
        break;
      case StringeeSignalingState.answered:
        _answerCall();
        break;
      case StringeeSignalingState.busy:
        _endCall(reason: 3);
        break;
      case StringeeSignalingState.ended:
        _endCall(reason: 2);
        break;
    }
    notifyListeners();
  }

  void _handleMediaStateChangeEvent(StringeeMediaState state) {
    _mediaState = state;
    notifyListeners();
  }

  void _handleReceiveCallInfoEvent(Map<dynamic, dynamic> info) {
    // push event to listener
    StringeeWrapper().stringeeListener?.onReceiveCallInfo?.call(info);
  }

  void _handleHandleOnAnotherDeviceEvent(StringeeSignalingState state) {
    /// if call state is busy, ended, answered, need to handle on platform
    /// end stringee call is not needed, sdk ended call already
    /// iOS: end callkit
    /// Android: dismiss notification or something else
    bool neededHandleOnPlatform = !state.isCalling && !state.isRinging;
    if (neededHandleOnPlatform) {
      if (isIOS) {
        CallkeepManager().reportEndCallIfNeeded(stringeeCallModel: this);
      } else {
        // TODO: - handle handleOnAnotherDevice on android if needed
      }
    }
  }

  /// Invoked when get Local stream in video call
  void _handleReceiveLocalStreamEvent(String callId) {
    if (call.callId == callId) {
      _receivedLocalStream = true;
      notifyListeners();
    }
  }

  /// Invoked when get Remote stream in video call
  void _handleReceiveRemoteStreamEvent(String callId) {
    if (call.callId == callId) {
      _receivedRemoteStream = true;
      notifyListeners();
    }
  }

  /// Invoked when add new video track to call in video call
  void _handleAddVideoTrackEvent(StringeeVideoTrack track) {}

  /// Invoked when remove video in call in video call
  void _handleRemoveVideoTrackEvent(StringeeVideoTrack track) {}

  /// Invoked when change Audio device in android
  void _handleChangeAudioDeviceEvent(
      AudioDevice audioDevice, List<AudioDevice> availableAudioDevices) {
    // TODO: - handle change audio device
    debugPrint('handleChangeAudioDeviceEvent - $audioDevice');
  }

  /// Make call
  /// required [from] and [to]
  /// optional [customData] and [videoQuality]
  /// return [Result]
  Future<Result> makeCall() async {
    if (from == null || to == null) {
      return Result.failure('from or to cannot be null');
    }
    MakeCallParams params = MakeCallParams(
      from!,
      to!,
      customData: customData,
      // isVideoCall: call2 != null,
      isVideoCall: call is StringeeCall2Wrapper,
      videoQuality: videoQuality,
    );

    final result = await call.makeCallFromParams(params);
    if (result['status']) {
      if (isIOS) {
        CallkeepManager().reportOutgoingCallIfNeeded(this);
      } else {
        // TODO: - handle outgoing call for android if needed
      }
      return Result.success(result);
    } else {
      return Result.failure('Error while making call');
    }
  }

  /// Call actions
  Future<Result> answerCall() async {
    return _answerCall();
  }

  Future<Result> hangupCall() async {
    return _endCall();
  }

  Future<Result> rejectCall() async {
    return _endCall();
  }

  Future<Result> muteCall() async {
    if (isIOS) {
      return CallkeepManager()
          .reportMuteCallIfNeeded(stringeeCallModel: this, muted: !_isMute);
    } else {
      return mute(!_isMute);
    }
  }

  Future<Result> switchCamera() async {
    final result = await call.switchCamera();
    if (result['status']) {
      return Result.success(result);
    } else {
      return Result.failure('Error while enableVideo');
    }
  }

  Future<Result> enableVideo() async {
    final result = await call.enableVideo(!_isVideoEnable);
    if (result['status']) {
      _isVideoEnable = !_isVideoEnable;
      notifyListeners();
      return Result.success(result);
    } else {
      return Result.failure('Error while enableVideo');
    }
  }

  Future<Result> changeSpeaker() async {
    final result = await call.setSpeakerphoneOn(!_isSpeaker);
    if (result['status']) {
      _isSpeaker = !_isSpeaker;
      notifyListeners();
      return Result.success(result);
    } else {
      return Result.failure('Error while changeSpeaker');
    }
  }

  Future<Result> _endCall({int? reason}) async {
    _timer?.cancel();
    _startedTimer = false;
    _time = '00:00';
    debugPrint('$uuid _endCall $uuid $_reportedEndCall reason: $reason');
    if (!_reportedEndCall) {
      _reportedEndCall = true;

      if (isIOS) {
        /// report end call if needed
        return CallkeepManager()
            .reportEndCallIfNeeded(stringeeCallModel: this, reason: reason);
      } else {
        // TODO: - handle call ended for android
        await StringeeCallManager.instance.endStringeeCall(this);
        return Result.success('Call ended successfully');
      }
    }
    notifyListeners();
    return Result.success('Call ended successfully');
  }

  Future<Result> _answerCall() async {
    startTimerIfNeeded();
    if (!_reportedAnsweredCall) {
      _reportedAnsweredCall = true;

      if (isIOS) {
        return CallkeepManager().answerCallIfNeeded(this);
      } else {
        // TODO: - handle call answered for android
        await StringeeCallManager.instance.answerStringeeCall(this);
        return Result.success('Call answered successfully');
      }
    }
    return Result.success('Call answered already');
  }

  startTimerIfNeeded() {
    if (!_startedTimer) {
      _startedTimer = true;
      _time = '00:00';
      _startCallTimer();
    }
    notifyListeners();
  }

  Future<Result> mute(bool muted) async {
    final result = await call.mute(muted);
    if (result['status']) {
      _isMute = muted;
      notifyListeners();
      return Result.success(result);
    } else {
      return Result.failure('Error while mute');
    }
  }
}
