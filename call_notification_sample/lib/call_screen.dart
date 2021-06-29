import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:ios_call_notification_sample/call_info.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import 'android_call_manager.dart';
import 'ios_call_manager.dart';
import 'sync_call.dart';

import 'common.dart' as common;

AndroidCallManager _androidCallManager = AndroidCallManager.shared;
IOsCallManager _iOsCallManager = IOsCallManager.shared;
bool isAndroid = Platform.isAndroid;
bool _isMute = false;
bool _isSpeakerOn;
bool _isVideoEnable;
bool _hasLocalStream = false;
bool _hasRemoteStream = false;
String _status = '';

class CallScreen extends StatefulWidget {
  final String toUserId;
  final String fromUserId;
  bool isVideo = false;
  bool showIncomingUI = false;
  bool dismissFuncCalled = false;

  CallScreen({
    Key key,
    @required this.fromUserId,
    @required this.toUserId,
    @required this.isVideo,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return CallScreenState();
  }
}

class CallScreenState extends State<CallScreen> implements CallInfo {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    if (isAndroid) {
      _androidCallManager.getCallInfo(this);
      _isSpeakerOn = widget.isVideo;
      _isVideoEnable = widget.isVideo;
      if (_androidCallManager.showIncomingCall) {
        widget.showIncomingUI = _androidCallManager.showIncomingCall;
      } else {
        makeOutgoingCall();
      }
    } else {
      if (_iOsCallManager.syncCall == null) {
        // Goi di
        makeOutgoingCall();
      } else {
        // Goi den
        widget.showIncomingUI = !_iOsCallManager.syncCall.userAnswered;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget NameCalling = new Container(
      alignment: Alignment.topCenter,
      padding: EdgeInsets.only(top: 120.0),
      child: new Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Container(
            alignment: Alignment.center,
            padding: EdgeInsets.only(bottom: 15.0),
            child: new Text(
              "${widget.toUserId}",
              style: new TextStyle(
                color: Colors.white,
                fontSize: 35.0,
              ),
            ),
          ),
          new Container(
            alignment: Alignment.center,
            child: new Text(
              isAndroid
                  ? _status
                  : '${_iOsCallManager.syncCall != null ? _iOsCallManager.syncCall.status : ""}',
              style: new TextStyle(
                color: Colors.white,
                fontSize: 20.0,
              ),
            ),
          )
        ],
      ),
    );

    Widget BottomContainer = new Container(
      padding: EdgeInsets.only(bottom: 30.0),
      alignment: Alignment.bottomCenter,
      child: new Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: widget.showIncomingUI
              ? <Widget>[
                  new Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      new GestureDetector(
                        onTap: rejectCallTapped,
                        child: Image.asset(
                          'images/end.png',
                          height: 75.0,
                          width: 75.0,
                        ),
                      ),
                      new GestureDetector(
                        onTap: acceptCallTapped,
                        child: Image.asset(
                          'images/answer.png',
                          height: 75.0,
                          width: 75.0,
                        ),
                      ),
                    ],
                  )
                ]
              : <Widget>[
                  new Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      new ButtonSpeaker(),
                      new ButtonMicro(),
                      new ButtonVideo(isVideo: widget.isVideo),
                    ],
                  ),
                  new Container(
                    padding: EdgeInsets.only(top: 20.0, bottom: 20.0),
                    child: new GestureDetector(
                      onTap: endCallTapped,
                      child: Image.asset(
                        'images/end.png',
                        height: 75.0,
                        width: 75.0,
                      ),
                    ),
                  )
                ]),
    );

    Widget localView = (isAndroid ? _hasLocalStream : _iOsCallManager.syncCall.hasLocalStream)
        ? new StringeeVideoView(
            isAndroid
                ? _androidCallManager.stringeeCall.id
                : _iOsCallManager.syncCall.stringeeCall.id,
            true,
            color: Colors.white,
            alignment: Alignment.topRight,
            isOverlay: true,
            margin: EdgeInsets.only(top: 100.0, right: 25.0),
            height: 200.0,
            width: 150.0,
            scalingType: ScalingType.fill,
          )
        : Placeholder();

    Widget remoteView = (isAndroid ? _hasRemoteStream : _iOsCallManager.syncCall.hasRemoteStream)
        ? new StringeeVideoView(
            isAndroid
                ? _androidCallManager.stringeeCall.id
                : _iOsCallManager.syncCall.stringeeCall.id,
            false,
            color: Colors.blue,
            isOverlay: false,
            isMirror: false,
            scalingType: ScalingType.fill,
          )
        : Placeholder();

    return new Scaffold(
      backgroundColor: Colors.black,
      body: new Stack(
        children: <Widget>[
          remoteView,
          localView,
          NameCalling,
          BottomContainer,
          widget.isVideo ? ButtonSwitchCamera() : Placeholder(),
        ],
      ),
    );
  }

  Future makeOutgoingCall() async {
    final parameters = {
      'from': widget.fromUserId,
      'to': widget.toUserId,
      'isVideoCall': widget.isVideo,
      'customData': null,
      'videoQuality': VideoQuality.hd,
    };

    if (isAndroid) {
      _androidCallManager.setStringeeCall(new StringeeCall(common.client), widget.isVideo);
      _androidCallManager.addListenerForCall();
      _androidCallManager.stringeeCall.makeCall(parameters).then((result) {
        bool status = result['status'];
        int code = result['code'];
        String message = result['message'];
        print(
            'MakeCall CallBack --- $status - $code - $message - ${_androidCallManager.stringeeCall.id} - ${_androidCallManager.stringeeCall.from} - ${_androidCallManager.stringeeCall.to}');

        if (!status) {
          _androidCallManager.clearDataEndDismiss();
        }
      });
    } else {
      var outgoingCall = StringeeCall(common.client);
      _iOsCallManager.syncCall = SyncCall();
      _iOsCallManager.syncCall.stringeeCall = outgoingCall;
      _iOsCallManager.addListenerForCall();

      outgoingCall.makeCall(parameters).then((result) {
        bool status = result['status'];
        int code = result['code'];
        String message = result['message'];
        print(
            'MakeCall CallBack --- $status - $code - $message - ${outgoingCall.id} - ${outgoingCall.from} - ${outgoingCall.to}');

        _iOsCallManager.syncCall.attachCall(outgoingCall);

        if (!status) {
          _iOsCallManager.clearDataEndDismiss();
        }
      });
    }
  }

  void endCallTapped() {
    if (isAndroid) {
      _androidCallManager.stringeeCall.hangup().then((result) {
        print('_endCallTapped -- ${result['message']}');
        if (result['status']) {
          _androidCallManager.clearDataEndDismiss();
        }
      });
    } else {
      if (_iOsCallManager.syncCall == null) {
        return;
      }

      _iOsCallManager.syncCall.hangup();
    }
  }

  void acceptCallTapped() {
    if (isAndroid) {
      _androidCallManager.stringeeCall.answer().then((result) {
        print('_acceptCallTapped -- ${result['message']}');
        if (result['status']) {
          setState(() {
            widget.showIncomingUI = !widget.showIncomingUI;
          });
        } else {
          _androidCallManager.clearDataEndDismiss();
        }
      });
    } else {
      // Tạm thời chưa xử lý button này vì các thư viện Callkit bên flutter chưa hỗ trở API để answer Callkit Call
      // Người dùng vẫn có thể click answer từ màn hình callkit bình thường
      return;

      if (_iOsCallManager.syncCall == null) {
        return;
      }

      _iOsCallManager.syncCall.userAnswered = true;
      _iOsCallManager.syncCall.answerIfConditionPassed();
    }
  }

  void rejectCallTapped() {
    if (isAndroid) {
      _androidCallManager.stringeeCall.reject().then((result) {
        print('_rejectCallTapped -- ${result['message']}');
        if (result['status']) {
          _androidCallManager.clearDataEndDismiss();
        }
      });
    } else {
      if (_iOsCallManager.syncCall == null) {
        return;
      }
      _iOsCallManager.syncCall.userRejected = true;
      _iOsCallManager.syncCall.reject().then((status) {
        if (Platform.isAndroid) {
          _iOsCallManager.clearDataEndDismiss();
        }
      });
    }
  }

  void changeToCallingUI() {
    setState(() {
      widget.showIncomingUI = false;
    });
  }

  void dismiss() {
    if (isAndroid) {
      Navigator.pop(context);
    } else {
      if (widget.dismissFuncCalled) {
        return;
      }
      widget.dismissFuncCalled = !widget.dismissFuncCalled;
      Navigator.pop(context);
    }
  }

  @override
  void onMuteState(bool isMute) {
    setState(() {
      _isMute = isMute;
    });
  }

  @override
  void onReceiveLocalStream() {
    setState(() {
      _hasLocalStream = true;
    });
  }

  @override
  void onReceiveRemoteStream() {
    setState(() {
      _hasRemoteStream = true;
    });
  }

  @override
  void onSpeakerState(bool isSpeakerOn) {
    if (mounted) {
      setState(() {
        _isSpeakerOn = isSpeakerOn;
      });
    }
  }

  @override
  void onStatusChange(String status) {
    setState(() {
      _status = status;
    });
  }

  @override
  void onVideoState(bool isVideoEnable) {
    setState(() {
      _isVideoEnable = isVideoEnable;
    });
  }
}

class ButtonSwitchCamera extends StatefulWidget {
  ButtonSwitchCamera({Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ButtonSwitchCameraState();
}

class _ButtonSwitchCameraState extends State<ButtonSwitchCamera> {
  void _toggleSwitchCamera() {
    if (isAndroid) {
      _androidCallManager.switchCamera();
    } else {
      if (_iOsCallManager.syncCall == null) {
        return;
      }

      _iOsCallManager.syncCall.switchCamera();
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return new Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 50.0, top: 50.0),
        child: new GestureDetector(
          onTap: _toggleSwitchCamera,
          child: Image.asset(
            'images/switch_camera.png',
            height: 30.0,
            width: 30.0,
          ),
        ),
      ),
    );
  }
}

class ButtonSpeaker extends StatefulWidget {
  ButtonSpeaker({
    Key key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ButtonSpeakerState();
}

class _ButtonSpeakerState extends State<ButtonSpeaker> {
  void _toggleSpeaker() {
    if (isAndroid) {
      _androidCallManager.setSpeakerphoneOn();
    } else {
      if (_iOsCallManager.syncCall == null) {
        return;
      }

      _iOsCallManager.syncCall.setSpeakerphoneOn();
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return new GestureDetector(
      onTap: _toggleSpeaker,
      child: Image.asset(
        (isAndroid ? _isSpeakerOn : _iOsCallManager.syncCall.isSpeaker)
            ? 'images/ic_speaker_on.png'
            : 'images/ic_speaker_off.png',
        height: 75.0,
        width: 75.0,
      ),
    );
  }
}

class ButtonMicro extends StatefulWidget {
  ButtonMicro({
    Key key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ButtonMicroState();
}

class _ButtonMicroState extends State<ButtonMicro> {
  void _toggleMicro() {
    if (isAndroid) {
      _androidCallManager.mute();
    } else {
      if (_iOsCallManager.syncCall == null) {
        return;
      }

      _iOsCallManager.syncCall.mute();
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return new GestureDetector(
      onTap: _toggleMicro,
      child: Image.asset(
        (isAndroid ? _isMute : _iOsCallManager.syncCall.isMute)
            ? 'images/ic_mute.png'
            : 'images/ic_mic.png',
        height: 75.0,
        width: 75.0,
      ),
    );
  }
}

class ButtonVideo extends StatefulWidget {
  final bool isVideo;

  ButtonVideo({Key key, @required this.isVideo}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ButtonVideoState();
}

class _ButtonVideoState extends State<ButtonVideo> {
  void _toggleVideo() {
    if (isAndroid) {
      _androidCallManager.enableVideo();
    } else {
      if (_iOsCallManager.syncCall == null) {
        return;
      }

      _iOsCallManager.syncCall.enableVideo();
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return new GestureDetector(
      onTap: widget.isVideo ? _toggleVideo : null,
      child: Image.asset(
        (isAndroid ? _isVideoEnable : _iOsCallManager.syncCall.videoEnabled)
            ? 'images/ic_video.png'
            : 'images/ic_video_off.png',
        height: 75.0,
        width: 75.0,
      ),
    );
  }
}
