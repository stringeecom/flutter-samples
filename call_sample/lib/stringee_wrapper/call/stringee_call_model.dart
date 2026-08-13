import 'dart:async';

import 'package:call_sample/stringee_wrapper/stringee_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

import '../common/common.dart';
import '../interfaces/stringee_call_interface.dart';
import '../push_manager/android_push_manager.dart';
import '../push_manager/callkeep_manager.dart';
import 'stringee_call_manager.dart';

/// Observable UI state for one incoming or outgoing Stringee call.
///
/// The model combines signaling and media events, owns the unanswered-call
/// timeout, exposes call controls, and makes end/answer reporting idempotent
/// across SDK, notification, and CallKit callbacks.
class StringeeCallModel extends ChangeNotifier {
  /// Call implementation wrapped as a common interface.
  final StringeeCallInterface call;

  /// Whether this model represents an incoming call.
  final bool isIncomingCall;

  /// Outgoing caller ID supplied by the application.
  final String? from;

  /// Outgoing callee ID supplied by the application.
  final String? to;

  /// Optional application data sent when making the call.
  final Map<dynamic, dynamic>? customData;

  /// Requested outgoing video quality.
  final VideoQuality? videoQuality;
  final bool? _outgoingIsVideoCall;

  /// call properties
  StringeeSignalingState _signalingState = StringeeSignalingState.calling;
  StringeeMediaState _mediaState = StringeeMediaState.disconnected;

  /// Current high-level UI lifecycle state.
  CallState callState = CallState.calling;

  AudioDevice _audioDevice = AudioDevice(audioType: AudioType.earpiece);
  List<AudioDevice> _availableAudioDevices = [];
  StringeeAudioEvent? _event;
  bool _initializingAudio = true;

  /// Currently selected audio device.
  AudioDevice get audioDevice => _audioDevice;

  /// Audio devices currently reported by the platform.
  List<AudioDevice> get availableAudioDevices => _availableAudioDevices;

  /// Overrides the latest signaling state used by lifecycle guards.
  set signalingState(StringeeSignalingState value) {
    _signalingState = value;
  }

  StreamSubscription<dynamic>? _callEventSubscription;

  // video track if
  StringeeVideoTrack? _localVideoTrack;

  /// Current Call2 local screen-share/video track, when emitted.
  StringeeVideoTrack? get localVideoTrack => _localVideoTrack;

  StringeeVideoTrack? _remoteVideoTrack;

  /// Current Call2 remote screen-share/video track, when emitted.
  StringeeVideoTrack? get remoteVideoTrack => _remoteVideoTrack;

  bool _isMute = false;

  /// Whether microphone transmission is muted.
  bool get isMute => _isMute;

  bool _isVideoEnable = true;

  /// Whether camera transmission is enabled.
  bool get isVideoEnable => _isVideoEnable;

  String _uuid = '';

  /// CallKit UUID associated with this model, or an empty string on Android.
  String get uuid => _uuid;

  /// Associates this call with CallKit [uuid].
  void setUuid(String uuid) {
    _uuid = uuid;
  }

  /// Whether this is a voice or video call.
  bool get isVideoCall {
    return _outgoingIsVideoCall ?? call.isVideoCall;
  }

  /// flag to check if local and remote stream is received
  bool _receivedLocalStream = false;
  bool _receivedRemoteStream = false;

  /// Whether the native local renderer is ready to be inserted in the UI.
  bool get readyLocalView => isVideoCall && _receivedLocalStream;

  /// Whether the native remote renderer is ready to be inserted in the UI.
  bool get readyRemoteView => isVideoCall && _receivedRemoteStream;

  /// call timer && flag to check if timer is started
  Timer? _timer;
  bool _startedTimer = false;

  Timer? _callTimeOutTimer;

  /// Connected-call duration formatted as `mm:ss`.
  String _time = '00:00';

  String get time => _time;

  /// Remote party shown in the call UI.
  String? get callee {
    return isIncomingCall ? call.from : call.to;
  }

  /// flags
  // flag to check if call is reported end call
  bool _reportedEndCall = false;

  // flag to check if call is reported answered call
  bool _reportedAnsweredCall = false;
  bool _released = false;

  /// Whether ending the call should use reject instead of hangup.
  bool get isShouldReject =>
      isIncomingCall && _signalingState != StringeeSignalingState.answered;

  /// Creates a model and starts its bounded pre-connected timeout.
  StringeeCallModel(
    this.call, {
    this.isIncomingCall = true,
    this.from,
    this.to,
    this.customData,
    this.videoQuality,
    bool? isVideoCall,
  }) : _outgoingIsVideoCall = isVideoCall {
    _event = StringeeAudioEvent(
      onChangeAudioDevice: (selectedAudioDevice, availableAudioDevices) {
        debugPrint('onChangeAudioDevice - $selectedAudioDevice');
        debugPrint('onChangeAudioDevice - $availableAudioDevices');
        _availableAudioDevices = availableAudioDevices;
        if (_initializingAudio) {
          _initializingAudio = false;
          int bluetoothIndex = -1;
          int wiredHeadsetIndex = -1;
          int speakerIndex = -1;
          int earpieceIndex = -1;
          for (var element in availableAudioDevices) {
            if (element.audioType == AudioType.bluetooth) {
              bluetoothIndex = availableAudioDevices.indexOf(element);
            }
            if (element.audioType == AudioType.wiredHeadset) {
              wiredHeadsetIndex = availableAudioDevices.indexOf(element);
            }
            if (element.audioType == AudioType.speakerPhone) {
              speakerIndex = availableAudioDevices.indexOf(element);
            }
            if (element.audioType == AudioType.earpiece) {
              earpieceIndex = availableAudioDevices.indexOf(element);
            }
          }
          if (bluetoothIndex != -1) {
            selectedAudioDevice = availableAudioDevices.elementAt(
              bluetoothIndex,
            );
          } else if (wiredHeadsetIndex != -1) {
            selectedAudioDevice = availableAudioDevices.elementAt(
              wiredHeadsetIndex,
            );
          } else if (this.isVideoCall) {
            if (speakerIndex != -1) {
              selectedAudioDevice = availableAudioDevices.elementAt(
                speakerIndex,
              );
            }
          } else {
            if (earpieceIndex != -1) {
              selectedAudioDevice = availableAudioDevices.elementAt(
                earpieceIndex,
              );
            }
          }
        }
        _changeAudioDevice(selectedAudioDevice);
      },
    );
    StringeeAudioManager().addListener(_event!);

    _callEventSubscription = call.eventStreamController.stream.listen((event) {
      debugPrint('$uuid StringeeCallModel ${call.callId} - event: $event');
      _handleStringeeCallEvent(event as Map<dynamic, dynamic>);
    });

    callState = isIncomingCall ? CallState.incoming : CallState.calling;

    // start time out
    _callTimeOutTimer = Timer(
      Duration(seconds: StringeeWrapper().callTimeout),
      () async {
        if (callState != CallState.started) {
          await _endCall();
        }
      },
    );
  }

  Future<void> _handleStringeeCallEvent(Map<dynamic, dynamic> event) async {
    switch (event['eventType']) {
      /// StringeeCallEvents
      case StringeeCallEvents.didChangeSignalingState:
        await _handleSignalingStateChangeEvent(event['body']);
        break;
      case StringeeCallEvents.didChangeMediaState:
        _handleMediaStateChangeEvent(event['body']);
        break;
      case StringeeCallEvents.didReceiveCallInfo:
        _handleReceiveCallInfoEvent(event['body']);
        break;
      case StringeeCallEvents.didHandleOnAnotherDevice:
        await _handleHandleOnAnotherDeviceEvent(event['body']);
        break;
      case StringeeCallEvents.didReceiveLocalStream:
        _handleReceiveLocalStreamEvent(event['body']);
        break;
      case StringeeCallEvents.didReceiveRemoteStream:
        _handleReceiveRemoteStreamEvent(event['body']);
        break;

      /// StringeeCall2Events
      case StringeeCall2Events.didChangeSignalingState:
        await _handleSignalingStateChangeEvent(event['body']);
        break;
      case StringeeCall2Events.didChangeMediaState:
        _handleMediaStateChangeEvent(event['body']);
        break;
      case StringeeCall2Events.didReceiveCallInfo:
        _handleReceiveCallInfoEvent(event['body']);
        break;
      case StringeeCall2Events.didHandleOnAnotherDevice:
        await _handleHandleOnAnotherDeviceEvent(event['body']);
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
    }
  }

  void _startCallTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      int second = timer.tick.toDouble().remainder(60).toInt();
      int minute = timer.tick.toDouble() ~/ 60;
      _time =
          '${minute < 10 ? '0$minute' : minute}:${second < 10 ? '0$second' : second}';
      try {
        notifyListeners();
      } catch (e) {
        debugPrint('StringeeCallModel disposed before notifyListeners: $e');
      }
    });
  }

  /// Invoked when get Signaling state
  Future<void> _handleSignalingStateChangeEvent(
    StringeeSignalingState state,
  ) async {
    signalingState = state;
    debugPrint('_handleSignalingStateChangeEvent $state');
    switch (state) {
      case StringeeSignalingState.calling:
        callState = CallState.calling;
        break;
      case StringeeSignalingState.ringing:
        callState = CallState.ringing;
        break;
      case StringeeSignalingState.answered:
        callState = CallState.starting;
        if (isIOS && !isIncomingCall && !_reportedAnsweredCall) {
          _reportedAnsweredCall = true;
          await CallkeepManager().answerCallIfNeeded(this);
        }
        if (_mediaState == StringeeMediaState.connected) {
          startTimerIfNeeded();
          callState = CallState.started;
          if (!isIOS) {
            unawaited(AndroidPushManager().markCallConnected(this));
          }
        }
        break;
      case StringeeSignalingState.busy:
        callState = CallState.busy;
        await _endCall(reason: 3);
        break;
      case StringeeSignalingState.ended:
        callState = CallState.ended;
        await _endCall(reason: 2);
        break;
    }
    try {
      notifyListeners();
    } catch (e) {
      debugPrint('StringeeCallModel disposed before notifyListeners: $e');
    }
  }

  void _handleMediaStateChangeEvent(StringeeMediaState state) {
    debugPrint('_handleMediaStateChangeEvent $state');
    _mediaState = state;
    if (_mediaState == StringeeMediaState.connected) {
      // set speaker if needed
      _callTimeOutTimer?.cancel();
      if (_signalingState == StringeeSignalingState.answered) {
        startTimerIfNeeded();
        callState = CallState.started;
        if (!isIOS) {
          unawaited(AndroidPushManager().markCallConnected(this));
        }
      }
    }
    try {
      notifyListeners();
    } catch (e) {
      debugPrint('StringeeCallModel disposed before notifyListeners: $e');
    }
  }

  void _handleReceiveCallInfoEvent(Map<dynamic, dynamic> info) {
    // push event to listener
    StringeeWrapper().stringeeListener?.onReceiveCallInfo?.call(info);
  }

  Future<void> _handleHandleOnAnotherDeviceEvent(
    StringeeSignalingState state,
  ) async {
    /// if call state is busy, ended, answered, need to handle on platform
    /// end stringee call is not needed, sdk ended call already
    /// iOS: end callkit
    /// Android: dismiss notification or something else
    if (state != StringeeSignalingState.calling &&
        state != StringeeSignalingState.ringing) {
      if (isIOS) {
        // report end call if needed
        // reason -1000: handleOnAnotherDevice, do not need end stringee call
        await CallkeepManager().reportEndCallIfNeeded(
          stringeeCallModel: this,
          reason: -1000,
        );
      }
      StringeeCallManager().clear(this);
      try {
        notifyListeners();
      } catch (e) {
        debugPrint('StringeeCallModel disposed before notifyListeners: $e');
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
  void _handleAddVideoTrackEvent(StringeeVideoTrack track) {
    if (track.isLocal) {
      _localVideoTrack = track;
    } else {
      _remoteVideoTrack = track;
    }
    try {
      notifyListeners();
    } catch (e) {
      debugPrint('StringeeCallModel disposed before notifyListeners: $e');
    }
  }

  /// Invoked when remove video in call in video call
  void _handleRemoveVideoTrackEvent(StringeeVideoTrack track) {
    if (track.isLocal) {
      _localVideoTrack = null;
    } else {
      _remoteVideoTrack = null;
    }
    try {
      notifyListeners();
    } catch (e) {
      debugPrint('StringeeCallModel disposed before notifyListeners: $e');
    }
  }

  /// Starts the configured outgoing call and returns its SDK response.
  Future<Response> makeCall() async {
    if (from == null ||
        to == null ||
        from!.trim().isEmpty ||
        to!.trim().isEmpty) {
      return Response.failure('from and to cannot be null or empty');
    }
    MakeCallParams params = MakeCallParams(
      from!.trim(),
      to!.trim(),
      customData: customData,
      isVideoCall: isVideoCall,
      videoQuality: videoQuality,
    );

    final response = await call.makeCallFromParams(params);
    if (response['status']) {
      if (isIOS) {
        CallkeepManager().reportOutgoingCallIfNeeded(this);
      }
      return Response.success(response);
    } else {
      return Response.failure('Error while making call');
    }
  }

  /// Call actions
  /// Answers this incoming call once.
  Future<Response> answerCall() async {
    return _answerCall();
  }

  /// Ends an outgoing or active call once.
  Future<Response> hangupCall() async {
    return _endCall();
  }

  /// Rejects this incoming call once.
  Future<Response> rejectCall() async {
    return _endCall();
  }

  /// Toggles microphone mute through SDK or CallKit as appropriate.
  Future<Response> muteCall() async {
    if (isIOS) {
      return CallkeepManager().reportMuteCallIfNeeded(
        stringeeCallModel: this,
        muted: !_isMute,
      );
    } else {
      return mute(!_isMute);
    }
  }

  /// Switches between available cameras.
  Future<Response> switchCamera() async {
    final response = await call.switchCamera();
    if (response['status']) {
      return Response.success(response);
    } else {
      return Response.failure('Error while enableVideo');
    }
  }

  /// Toggles camera transmission.
  Future<Response> enableVideo() async {
    final response = await call.enableVideo(!_isVideoEnable);
    if (response['status']) {
      _isVideoEnable = !_isVideoEnable;
      notifyListeners();
      return Response.success(response);
    } else {
      return Response.failure('Error while enableVideo');
    }
  }

  /// Selects [device] as the active audio route.
  Future<Response> changeAudioDevice(AudioDevice device) async {
    return _changeAudioDevice(device);
  }

  Future<Response> _changeAudioDevice(AudioDevice device) async {
    final response = await call.changeAudioDevice(device);
    debugPrint('changeAudioDevice: $device, response: $response');
    if (response.status) {
      _audioDevice = device;
      try {
        notifyListeners();
      } catch (e) {
        debugPrint('StringeeCallModel disposed before notifyListeners: $e');
      }
      return Response.success(response);
    } else {
      return Response.failure('Error while changeSpeaker');
    }
  }

  Future<Response> _endCall({int? reason}) async {
    _timer?.cancel();
    _startedTimer = false;
    _time = '00:00';
    _callTimeOutTimer?.cancel();
    debugPrint('$uuid _endCall $uuid $_reportedEndCall reason: $reason');
    if (!_reportedEndCall) {
      _reportedEndCall = true;
      if (isIOS) {
        /// report end call if needed
        return CallkeepManager().reportEndCallIfNeeded(
          stringeeCallModel: this,
          reason: reason,
        );
      } else {
        if (callState != CallState.ended && callState != CallState.busy) {
          await StringeeCallManager().endStringeeCall(this);
        } else {
          StringeeCallManager().clear(this);
        }
      }
    }
    try {
      notifyListeners();
    } catch (e) {
      debugPrint('StringeeCallModel disposed before notifyListeners: $e');
    }
    return Response.success('Call ended successfully');
  }

  Future<Response> _answerCall() async {
    if (!_reportedAnsweredCall) {
      _reportedAnsweredCall = true;
      if (isIOS) {
        return CallkeepManager().answerCallIfNeeded(this);
      } else {
        final response = await StringeeCallManager().answerStringeeCall(this);
        if (response.isFailure) {
          _reportedAnsweredCall = false;
          return response;
        }
      }
    }
    notifyListeners();
    return Response.success('Call answered already');
  }

  /// Starts the connected-call timer if it has not already started.
  void startTimerIfNeeded() {
    if (!_startedTimer) {
      _startedTimer = true;
      _time = '00:00';
      _startCallTimer();
    }
    notifyListeners();
  }

  /// Applies an explicit microphone [muted] state.
  Future<Response> mute(bool muted) async {
    final response = await call.mute(muted);
    if (response['status']) {
      _isMute = muted;
      notifyListeners();
      return Response.success(response);
    } else {
      return Response.failure('Error while mute');
    }
  }

  @override
  void dispose() {
    release();
    debugPrint('dispose StringeeCallModel $uuid ${call.callId}');
    super.dispose();
  }

  /// Cancels timers, audio listeners, and the SDK event subscription once.
  void release() {
    if (_released) return;
    _released = true;
    _timer?.cancel();
    _callTimeOutTimer?.cancel();
    StringeeAudioManager().removeListener(_event!);
    StringeeAudioManager().stop();
    _callEventSubscription?.cancel();
  }
}
