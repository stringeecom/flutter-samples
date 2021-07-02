import 'package:flutter/material.dart';
import 'package:ios_call_notification_sample/models/call_info.dart';
import 'package:ios_call_notification_sample/screens/call_screen.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import 'instance_manager.dart' as InstanceManager;

class AndroidCallManager with WidgetsBindingObserver {
  static AndroidCallManager _instance;
  BuildContext _context;
  GlobalKey<CallScreenState> callScreenKey;
  StringeeCall _call;
  StringeeCall2 _call2;
  CallInfo _callInfo;

  bool _isAppInBackground = false;
  bool _showIncomingCall = false;
  bool _isVideoCall = false;
  bool _isSpeaker = false;
  bool _preSpeaker = false;
  bool _isVideoEnable = false;
  bool _isMute = false;
  bool _hasLocalStream = false;
  bool _useCall2 = false;
  bool _isInCall = false;

  String _callId = "";

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
    _useCall2 = false;
    _isInCall = true;
  }

  void setStringeeCall2(StringeeCall2 stringeeCall2, bool isVideoCall) {
    _call2 = stringeeCall2;
    _isVideoCall = isVideoCall;
    _isSpeaker = _isVideoCall;
    _isVideoEnable = _isVideoCall;
    _useCall2 = true;
    _isInCall = true;
  }

  void getCallInfo(CallInfo callInfo) {
    _callInfo = callInfo;
  }

  StringeeCall get stringeeCall => _call;

  StringeeCall2 get stringeeCall2 => _call2;

  bool get showIncomingCall => _showIncomingCall;

  String get callId => _callId;

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
    if (_isInCall) {
      reject();
    } else {
      _showIncomingCall = true;
      _isVideoCall = _call.isVideoCall;
      _isSpeaker = _call.isVideoCall;
      _isVideoEnable = _call.isVideoCall;
      _useCall2 = false;
      _callId = _call.id;
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
  }

  void handleIncomingCall2Event(StringeeCall2 call2, BuildContext context) {
    print("handleIncomingCall2Event, callId: " + call2.id);
    _call2 = call2;
    if (_isInCall) {
      reject();
    } else {
      _showIncomingCall = true;
      _isVideoCall = _call2.isVideoCall;
      _isSpeaker = _call2.isVideoCall;
      _isVideoEnable = _call2.isVideoCall;
      _useCall2 = true;
      _callId = _call2.id;
      addListenerForCall();

      _call2.initAnswer().then((event) {
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
  }

  void showCallScreen() {
    callScreenKey = GlobalKey<CallScreenState>();
    CallScreen callScreen = CallScreen(
      key: callScreenKey,
      fromUserId: _useCall2 ? _call2.to : _call.to,
      toUserId: _useCall2 ? _call2.from : _call.from,
      isVideo: _isVideoCall,
      useCall2: _useCall2,
    );
    Navigator.push(
      _context,
      MaterialPageRoute(builder: (context) => callScreen),
    );
  }

  void addListenerForCall() {
    if (_useCall2) {
      if (!_call2.eventStreamController.hasListener) {
        _call2.eventStreamController.stream.listen((event) {
          Map<dynamic, dynamic> map = event;
          switch (map['eventType']) {
            case StringeeCall2Events.didChangeSignalingState:
              handleSignalingStateChangeEvent(map['body']);
              break;
            case StringeeCall2Events.didChangeMediaState:
              handleMediaStateChangeEvent(map['body']);
              break;
            case StringeeCall2Events.didReceiveCallInfo:
              handleReceiveCallInfoEvent(map['body']);
              break;
            case StringeeCall2Events.didHandleOnAnotherDevice:
              handleHandleOnAnotherDeviceEvent(map['body']);
              break;
            case StringeeCall2Events.didReceiveLocalStream:
              handleReceiveLocalStreamEvent(map['body']);
              break;
            case StringeeCall2Events.didReceiveRemoteStream:
              handleReceiveRemoteStreamEvent(map['body']);
              break;
            case StringeeCall2Events.didChangeAudioDevice:
              handleChangeAudioDeviceEvent(map['selectedAudioDevice']);
              break;
            default:
              break;
          }
        });
      }
    } else {
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
          if (_useCall2) {
            if (_call2 != null) {
              _call2.setSpeakerphoneOn(_isSpeaker);
              if (_callInfo != null) {
                _callInfo.onSpeakerState(_isSpeaker);
              }
              if (_call2.isVideoCall && _hasLocalStream) {
                if (_callInfo != null) {
                  _callInfo.onReceiveLocalStream();
                }
              }
            }
          } else {
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
            (_useCall2 ? _call2.isVideoCall : _call.isVideoCall) &&
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
    if (_useCall2) {
      if (_call2.isVideoCall) {
        _callInfo.onReceiveRemoteStream();
      }
    } else {
      if (_call.isVideoCall) {
        _callInfo.onReceiveRemoteStream();
      }
    }
  }

  void handleChangeAudioDeviceEvent(AudioDevice audioDevice) {
    print('handleChangeAudioDeviceEvent - $audioDevice');
    switch (audioDevice) {
      case AudioDevice.speakerPhone:
      case AudioDevice.earpiece:
        _isSpeaker = _preSpeaker;
        if (_useCall2) {
          if (_call2 != null) {
            _call2.setSpeakerphoneOn(_isSpeaker);
            if (_callInfo != null) {
              _callInfo.onSpeakerState(_isSpeaker);
            }
          }
        } else {
          if (_call != null) {
            _call.setSpeakerphoneOn(_isSpeaker);
            if (_callInfo != null) {
              _callInfo.onSpeakerState(_isSpeaker);
            }
          }
        }
        break;
      case AudioDevice.bluetooth:
      case AudioDevice.wiredHeadset:
        _preSpeaker = _isSpeaker;
        _isSpeaker = false;
        if (_useCall2) {
          if (_call2 != null) {
            _call2.setSpeakerphoneOn(_isSpeaker);
            if (_callInfo != null) {
              _callInfo.onSpeakerState(_isSpeaker);
            }
          }
        } else {
          if (_call != null) {
            _call.setSpeakerphoneOn(_isSpeaker);
            if (_callInfo != null) {
              _callInfo.onSpeakerState(_isSpeaker);
            }
          }
        }
        break;
      case AudioDevice.none:
        print('handleChangeAudioDeviceEvent - non audio devices connected');
        break;
    }
  }

  void makeCall(Map<dynamic, dynamic> parameters) {
    if (_useCall2) {
      _call2.makeCall(parameters).then((result) {
        _callId = _call2.id;
        bool status = result['status'];
        int code = result['code'];
        String message = result['message'];
        print(
            'MakeCall CallBack --- $status - $code - $message - ${_call2.id} - ${_call2.from} - ${_call2.to}');

        _isInCall = status;
        if (!status) {
          clearDataEndDismiss();
        }
      });
    } else {
      _call.makeCall(parameters).then((result) {
        _callId = _call.id;
        bool status = result['status'];
        int code = result['code'];
        String message = result['message'];
        print(
            'MakeCall CallBack --- $status - $code - $message - ${_call.id} - ${_call.from} - ${_call.to}');
        _isInCall = status;
        if (!status) {
          clearDataEndDismiss();
        }
      });
    }
  }

  Future<Map<dynamic, dynamic>> answer() {
    if (_useCall2) {
      return _call2.answer();
    } else {
      return _call.answer();
    }
  }

  void clearDataEndDismiss() {
    print('clearDataEndDismiss');

    if (_useCall2) {
      if (_call2 != null) {
        _call2.destroy();
        _call2 = null;
      }
    } else {
      if (_call != null) {
        _call.destroy();
        _call = null;
      }
    }

    _isAppInBackground = false;
    _showIncomingCall = false;
    _isVideoCall = false;
    _isSpeaker = false;
    _preSpeaker = false;
    _isVideoEnable = false;
    _isMute = false;
    _hasLocalStream = false;
    _useCall2 = false;
    _isInCall = false;

    _callId = "";

    if (callScreenKey != null && callScreenKey.currentState != null) {
      callScreenKey.currentState.dismiss();
      callScreenKey = null;
    }
  }

  void switchCamera() {
    if (_useCall2) {
      _call2.switchCamera().then((result) {
        bool status = result['status'];
        if (status) {}
      });
    } else {
      _call.switchCamera().then((result) {
        bool status = result['status'];
        if (status) {}
      });
    }
  }

  void hangup() {
    if (_useCall2) {
      _call2.hangup().then((result) {
        if (result['status']) {
          clearDataEndDismiss();
        }
      });
    } else {
      _call.hangup().then((result) {
        if (result['status']) {
          clearDataEndDismiss();
        }
      });
    }
  }

  void reject() {
    if (_useCall2) {
      _call2.reject().then((result) {
        if (result['status']) {
          clearDataEndDismiss();
        }
      });
    } else {
      _call.reject().then((result) {
        if (result['status']) {
          clearDataEndDismiss();
        }
      });
    }
  }

  void setSpeakerphoneOn() {
    _isSpeaker = !_isSpeaker;
    if (_useCall2) {
      _call2.setSpeakerphoneOn(_isSpeaker).then((result) {
        bool status = result['status'];
        if (status) {
          if (_callInfo != null) {
            _callInfo.onSpeakerState(_isSpeaker);
          }
        }
      });
    } else {
      _call.setSpeakerphoneOn(_isSpeaker).then((result) {
        bool status = result['status'];
        if (status) {
          if (_callInfo != null) {
            _callInfo.onSpeakerState(_isSpeaker);
          }
        }
      });
    }
  }

  void mute() {
    if (_useCall2) {
      _call2.mute(!_isMute).then((result) {
        bool status = result['status'];
        if (status) {
          _isMute = !_isMute;
          if (_callInfo != null) {
            _callInfo.onMuteState(_isMute);
          }
        }
      });
    } else {
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
  }

  void enableVideo() {
    if (_useCall2) {
      _call2.enableVideo(!_isVideoEnable).then((result) {
        bool status = result['status'];
        if (status) {
          _isVideoEnable = !_isVideoEnable;
          if (_callInfo != null) {
            _callInfo.onVideoState(_isVideoEnable);
          }
        }
      });
    } else {
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
}
