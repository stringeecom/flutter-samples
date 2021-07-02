import 'package:flutter/material.dart';
import 'package:ios_call_notification_sample/models/call_info.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import 'package:ios_call_notification_sample/screens/call_screen.dart';
import 'instance_manager.dart' as InstanceManager;

class AndroidCallManager with WidgetsBindingObserver {
  static AndroidCallManager _instance;
  BuildContext _context;
  GlobalKey<CallScreenState> callScreenKey;
  StringeeCall _call;
  CallInfo _callInfo;

  bool _isAppInBackground = false;
  bool _showIncomingCall = false;
  bool _isVideoCall = false;
  bool _isSpeaker = false;
  bool _preSpeaker = false;
  bool _isVideoEnable = false;
  bool _isMute = false;
  bool _hasLocalStream = false;
  StringeeMediaState _mediaState;
  StringeeSignalingState _signalingState;

  static AndroidCallManager get shared {
    if (_instance == null) {
      _instance = AndroidCallManager._internal();
    }
    return _instance;
  }

  void setStringeeCall(StringeeCall stringeeCall, bool isVideoCall) {
    _call = stringeeCall;
    _isVideoCall = isVideoCall;
    _isSpeaker = _isVideoCall;
    _isVideoEnable = _isVideoCall;
  }

  void getCallInfo(CallInfo callInfo) {
    _callInfo = callInfo;
  }

  StringeeCall get stringeeCall => _call;

  bool get showIncomingCall => _showIncomingCall;

  void setContext(BuildContext context) {
    assert(context != null);
    _context = context;
  }

  AndroidCallManager._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  void destroy() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO: implement didChangeAppLifecycleState
    super.didChangeAppLifecycleState(state);
    print('didChangeAppLifecycleState = $state');
    if (state == AppLifecycleState.resumed) {
      InstanceManager.localNotifications.cancel(0);
      _isAppInBackground = false;
    } else if (state == AppLifecycleState.inactive) {
      _isAppInBackground = true;
    }

    if (state == AppLifecycleState.resumed && InstanceManager.client != null) {
      if (InstanceManager.client.hasConnected && _showIncomingCall) {
        showCallScreen();
      }
    }
  }

  void handleIncomingCallEvent(StringeeCall call, BuildContext context) {
    print("handleIncomingCallEvent, callId: " + call.id);
    _call = call;
    _showIncomingCall = true;
    _isVideoCall = _call.isVideoCall;
    _isSpeaker = _call.isVideoCall;
    _isVideoEnable = _call.isVideoCall;
    addListenerForCall();

    _call.initAnswer().then((event) {
      bool status = event['status'];
      if (!status) {
        clearDataEndDismiss();
      }
    });

    if (!_isAppInBackground) {
      showCallScreen();
    } else {
      _showIncomingCall = true;
    }
  }

  void handleIncomingCall2Event(StringeeCall2 call, BuildContext context) {}

  void showCallScreen() {
    callScreenKey = GlobalKey<CallScreenState>();
    CallScreen callScreen = CallScreen(
      key: callScreenKey,
      fromUserId: _call.to,
      toUserId: _call.from,
      isVideo: _isVideoCall,
    );
    Navigator.push(
      _context,
      MaterialPageRoute(builder: (context) => callScreen),
    );
  }

  void addListenerForCall() {
    if (!_call.eventStreamController.hasListener) {
      _call.eventStreamController.stream.listen((event) {
        Map<dynamic, dynamic> map = event;
        switch (map['eventType']) {
          case StringeeCallEvents.didChangeSignalingState:
            handleSignalingStateChangeEvent(map['body']);
            break;
          case StringeeCallEvents.didChangeMediaState:
            handleMediaStateChangeEvent(map['body']);
            break;
          case StringeeCallEvents.didReceiveCallInfo:
            handleReceiveCallInfoEvent(map['body']);
            break;
          case StringeeCallEvents.didHandleOnAnotherDevice:
            handleHandleOnAnotherDeviceEvent(map['body']);
            break;
          case StringeeCallEvents.didReceiveLocalStream:
            handleReceiveLocalStreamEvent(map['body']);
            break;
          case StringeeCallEvents.didReceiveRemoteStream:
            handleReceiveRemoteStreamEvent(map['body']);
            break;
          case StringeeCallEvents.didChangeAudioDevice:
            handleChangeAudioDeviceEvent(map['selectedAudioDevice']);
            break;
          default:
            break;
        }
      });
    }
  }

  /// Handle event for call

  void handleSignalingStateChangeEvent(StringeeSignalingState state) {
    print('handleSignalingStateChangeEvent - $state');
    _signalingState = state;
    _callInfo.onStatusChange(state.toString().split('.')[1]);
    switch (state) {
      case StringeeSignalingState.calling:
        break;
      case StringeeSignalingState.ringing:
        break;
      case StringeeSignalingState.answered:
        if (_mediaState == StringeeMediaState.connected) {
          if (_call != null) {
            _call.setSpeakerphoneOn(_isSpeaker);
            if (_callInfo != null) {
              _callInfo.onSpeakerState(_isSpeaker);
            }
            if (_call.isVideoCall && _hasLocalStream) {
              if (_callInfo != null) {
                _callInfo.onReceiveLocalStream();
              }
            }
          }
        }
        break;
      case StringeeSignalingState.busy:
        clearDataEndDismiss();
        break;
      case StringeeSignalingState.ended:
        clearDataEndDismiss();
        break;
      default:
        break;
    }
  }

  void handleMediaStateChangeEvent(StringeeMediaState state) {
    print('handleMediaStateChangeEvent - $state');
    _mediaState = state;
    _callInfo.onStatusChange(state.toString().split('.')[1]);
    switch (state) {
      case StringeeMediaState.connected:
        if (_signalingState == StringeeSignalingState.answered &&
            _call.isVideoCall &&
            _hasLocalStream) {
          if (_callInfo != null) {
            _callInfo.onReceiveLocalStream();
          }
        }
        break;
      case StringeeMediaState.disconnected:
        break;
      default:
        break;
    }
  }

  void handleReceiveCallInfoEvent(Map<dynamic, dynamic> info) {
    print('handleReceiveCallInfoEvent - $info');
  }

  void handleHandleOnAnotherDeviceEvent(StringeeSignalingState state) {
    print('handleHandleOnAnotherDeviceEvent - $state');
  }

  void handleReceiveLocalStreamEvent(String callId) {
    print('handleReceiveLocalStreamEvent - $callId');
    _hasLocalStream = true;
  }

  void handleReceiveRemoteStreamEvent(String callId) {
    print('handleReceiveRemoteStreamEvent - $callId');
    if (_call.isVideoCall) {
      _callInfo.onReceiveRemoteStream();
    }
  }

  void handleChangeAudioDeviceEvent(AudioDevice audioDevice) {
    print('handleChangeAudioDeviceEvent - $audioDevice');
    switch (audioDevice) {
      case AudioDevice.speakerPhone:
      case AudioDevice.earpiece:
        _isSpeaker = _preSpeaker;
        if (_call != null) {
          _call.setSpeakerphoneOn(_isSpeaker);
          if (_callInfo != null) {
            _callInfo.onSpeakerState(_isSpeaker);
          }
        }
        break;
      case AudioDevice.bluetooth:
      case AudioDevice.wiredHeadset:
        _preSpeaker = _isSpeaker;
        _isSpeaker = false;
        if (_call != null) {
          _call.setSpeakerphoneOn(_isSpeaker);
          if (_callInfo != null) {
            _callInfo.onSpeakerState(_isSpeaker);
          }
        }
        break;
      case AudioDevice.none:
        print('handleChangeAudioDeviceEvent - non audio devices connected');
        break;
    }
  }

  void clearDataEndDismiss() {
    print('clearDataEndDismiss');

    if (_call != null) {
      _call.destroy();
      _call = null;
    }

    if (callScreenKey != null && callScreenKey.currentState != null) {
      callScreenKey.currentState.dismiss();
      callScreenKey = null;
    }
  }

  void switchCamera() {
    _call.switchCamera().then((result) {
      bool status = result['status'];
      if (status) {}
    });
  }

  void setSpeakerphoneOn() {
    _isSpeaker = !_isSpeaker;
    _call.setSpeakerphoneOn(_isSpeaker).then((result) {
      bool status = result['status'];
      if (status) {
        if (_callInfo != null) {
          _callInfo.onSpeakerState(_isSpeaker);
        }
      }
    });
  }

  void mute() {
    _call.mute(!_isMute).then((result) {
      bool status = result['status'];
      if (status) {
        _isMute = !_isMute;
        if (_callInfo != null) {
          _callInfo.onMuteState(_isMute);
        }
      }
    });
  }

  void enableVideo() {
    _call.enableVideo(!_isVideoEnable).then((result) {
      bool status = result['status'];
      if (status) {
        _isVideoEnable = !_isVideoEnable;
        if (_callInfo != null) {
          _callInfo.onVideoState(_isVideoEnable);
        }
      }
    });
  }
}