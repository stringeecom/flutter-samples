import 'dart:async';

import 'package:call_sample/stringee_wrapper/interfaces/interfaces.dart';
import 'package:flutter/material.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../common/common.dart';
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
  bool _isMicOn = true;
  bool get isMicOn => _isMicOn;
  bool _isVideoEnable = true;
  bool get isVideoEnable => _isVideoEnable;
  bool _isSpeaker = false;
  bool get isSpeaker => _isSpeaker;

  bool get isInCall {
    if (mediaState == StringeeMediaState.connected) {
      debugPrint(
          'isInCall - mediaState connected - signalingState: $signalingState');
      return true;
    } else {
      return signalingState == StringeeSignalingState.answered;
    }
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

  // flag to check if call is reported end call
  bool _reportedEndCall = false;

  StringeeCallModel(
    this.call, {
    this.isIncomingCall = true,
    this.from,
    this.to,
    this.customData,
    this.videoQuality,
  }) {
    call.eventStreamController.stream.listen((event) {
      debugPrint('StringeeCallModel ${call.callId} - event: $event');
      _handleStringeeCallEvent(event as Map<dynamic, dynamic>);
    });

    // TODO: - make call when init or somewhere else ??
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

      /// This event only for android
      case StringeeCall2Events.didChangeAudioDevice:
        if (!isIOS) {
          _handleChangeAudioDeviceEvent(
              event['selectedAudioDevice'], event['availableAudioDevices']);
        }
        break;
      default:
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
    debugPrint('handleSignalingStateChangeEvent - $state');
    // TODO: - handle signaling state
    _signalingState = state;
    switch (state) {
      case StringeeSignalingState.calling:
        break;
      case StringeeSignalingState.ringing:
        break;
      case StringeeSignalingState.answered:
        if (!_startedTimer) {
          _startedTimer = true;
          _time = '00:00';
          _startCallTimer();
        }
        StringeeCallManager.instance.answeredCall(this);
        break;
      case StringeeSignalingState.busy:
        _timer?.cancel();
        _startedTimer = false;
        _time = '00:00';

        if (!_reportedEndCall) {
          StringeeCallManager.instance.endedCall(this);
          _reportedEndCall = true;
        }
        break;
      case StringeeSignalingState.ended:
        _timer?.cancel();
        _startedTimer = false;
        _time = '00:00';

        if (!_reportedEndCall) {
          _reportedEndCall = true;
          StringeeCallManager.instance.endedCall(this);
        }
        break;
    }
    notifyListeners();
  }

  /// Invoked when get Media state
  void _handleMediaStateChangeEvent(StringeeMediaState state) {
    debugPrint('handleMediaStateChangeEvent - $state');
    _mediaState = state;
    notifyListeners();
  }

  /// Invoked when get Call info
  void _handleReceiveCallInfoEvent(Map<dynamic, dynamic> info) {
    debugPrint('handleReceiveCallInfoEvent - $info');
    // TODO: - handle call info
  }

  /// Invoked when an incoming call is handle on another device
  void _handleHandleOnAnotherDeviceEvent(StringeeSignalingState state) {
    debugPrint('handleHandleOnAnotherDeviceEvent - $state');
    // TODO: - handle handleOnAnotherDevice
  }

  /// Invoked when get Local stream in video call
  void _handleReceiveLocalStreamEvent(String callId) {
    debugPrint('handleReceiveLocalStreamEvent - $callId ${call.callId}');
    if (call.callId == callId) {
      _receivedLocalStream = true;
      notifyListeners();
    }
  }

  /// Invoked when get Remote stream in video call
  void _handleReceiveRemoteStreamEvent(String callId) {
    debugPrint('handleReceiveRemoteStreamEvent - $callId ${call.callId}');
    if (call.callId == callId) {
      _receivedRemoteStream = true;
      notifyListeners();
    }
  }

  /// Invoked when add new video track to call in video call
  void _handleAddVideoTrackEvent(StringeeVideoTrack track) {
    debugPrint('handleAddVideoTrackEvent - ${track.id}');
  }

  /// Invoked when remove video in call in video call
  void _handleRemoveVideoTrackEvent(StringeeVideoTrack track) {
    debugPrint('handleRemoveVideoTrackEvent - ${track.id}');
  }

  /// Invoked when change Audio device in android
  void _handleChangeAudioDeviceEvent(
      AudioDevice audioDevice, List<AudioDevice> availableAudioDevices) {
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
      StringeeCallManager.instance.madeCall(this);
      return Result.success(result);
    } else {
      return Result.failure('Error while making call');
    }
  }

  /// Call actions
  Future<Result> answerCall() async {
    final result = await call.answer();
    // TODO: - handle answer call result
    if (result['status']) {
      if (!_startedTimer) {
        _startedTimer = true;
        _time = '00:00';
        _startCallTimer();
      }
      return Result.success(result);
    } else {
      return Result.failure('Error while answerCall');
    }
  }

  Future<Result> hangupCall() async {
    final result = await call.hangup();
    // TODO: - handle hangupCall result
    if (result['status']) {
      _timer?.cancel();
      _startedTimer = false;
      _time = '00:00';
      if (!_reportedEndCall) {
        StringeeCallManager.instance.endedCall(this);
        _reportedEndCall = true;
      }
      return Result.success('Call ended successfully');
    } else {
      return Result.failure('Error while hangupCall');
    }
  }

  Future<Result> rejectCall() async {
    final result = await call.reject();
    // TODO: - handle rejectCall result
    if (result['status']) {
      _timer?.cancel();
      _startedTimer = false;
      _time = '00:00';
      if (!_reportedEndCall) {
        StringeeCallManager.instance.endedCall(this);
        _reportedEndCall = true;
      }
      return Result.success('Call rejected successfully');
    } else {
      return Result.failure('Error while rejectCall');
    }
  }

  Future<Result> muteCall() async {
    final result = await call.mute(!_isMicOn);
    if (result['status']) {
      _isMicOn = !_isMicOn;
      notifyListeners();
      return Result.success(result);
    } else {
      return Result.failure('Error while enableVideo');
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
}
