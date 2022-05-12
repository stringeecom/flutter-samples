import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';
import 'call_manager.dart';
import 'sync_call.dart';

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

class CallScreenState extends State<CallScreen> {
  String status = "";

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    if (CallManager.shared.syncCall == null) {
      // Goi di
      makeOutgoingCall();
    } else {
      // Goi den
      widget.showIncomingUI = !CallManager.shared.syncCall.userAnswered;
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
              '${CallManager.shared.syncCall != null ? CallManager.shared.syncCall.status : ""}',
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

    Widget localView = CallManager.shared.syncCall.hasLocalStream
        ? new StringeeVideoView(
      CallManager.shared.syncCall.stringeeCall.id,
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

    Widget remoteView = CallManager.shared.syncCall.hasRemoteStream
        ? new StringeeVideoView(
      CallManager.shared.syncCall.stringeeCall.id,
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

      var outgoingCall = StringeeCall();
      CallManager.shared.syncCall = SyncCall();
      CallManager.shared.syncCall.stringeeCall = outgoingCall;
      CallManager.shared.addListenerForCall();

      outgoingCall.makeCall(parameters).then((result) {
        bool status = result['status'];
        int code = result['code'];
        String message = result['message'];
        print('MakeCall CallBack --- $status - $code - $message - ${outgoingCall.id} - ${outgoingCall.from} - ${outgoingCall.to}');

        CallManager.shared.syncCall.attachCall(outgoingCall);

        if (!status) {
          CallManager.shared.clearDataEndDismiss();
        }
      });
    // }
  }

  void endCallTapped() {
    if (CallManager.shared.syncCall == null) {
      return;
    }

    CallManager.shared.syncCall.hangup().then((status) {
      if (Platform.isAndroid) {
        CallManager.shared.clearDataEndDismiss();
      }
    });
  }

  void acceptCallTapped() {
    // Tạm thời chưa xử lý button này vì các thư viện Callkit bên flutter chưa hỗ trở API để answer Callkit Call
    // Người dùng vẫn có thể click answer từ màn hình callkit bình thường
    return;

    if (CallManager.shared.syncCall == null) {
      return;
    }

    CallManager.shared.syncCall.userAnswered = true;
    CallManager.shared.syncCall.answerIfConditionPassed();
  }

  void rejectCallTapped() {
    if (CallManager.shared.syncCall == null) {
      return;
    }
    CallManager.shared.syncCall.userRejected = true;
    CallManager.shared.syncCall.reject().then((status) {
      if (Platform.isAndroid) {
        CallManager.shared.clearDataEndDismiss();
      }
    });
  }

  void changeToCallingUI() {
    setState(() {
      widget.showIncomingUI = false;
    });
  }

  void dismiss() {
    if (widget.dismissFuncCalled) {
      return;
    }
    widget.dismissFuncCalled = !widget.dismissFuncCalled;
    Navigator.pop(context);
  }
}

class ButtonSwitchCamera extends StatefulWidget {
  ButtonSwitchCamera({
    Key key
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ButtonSwitchCameraState();
}

class _ButtonSwitchCameraState extends State<ButtonSwitchCamera> {

  void _toggleSwitchCamera() {
    if (CallManager.shared.syncCall == null) {
      return;
    }

    CallManager.shared.syncCall.switchCamera();
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
    if (CallManager.shared.syncCall == null) {
      return;
    }

    CallManager.shared.syncCall.setSpeakerphoneOn();
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
        CallManager.shared.syncCall.isSpeaker ? 'images/ic_speaker_off.png' : 'images/ic_speaker_on.png',
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
    if (CallManager.shared.syncCall == null) {
      return;
    }

    CallManager.shared.syncCall.mute();
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
        CallManager.shared.syncCall.isMute ? 'images/ic_mute.png' : 'images/ic_mic.png',
        height: 75.0,
        width: 75.0,
      ),
    );
  }
}

class ButtonVideo extends StatefulWidget {
  final bool isVideo;

  ButtonVideo({
    Key key,
    @required this.isVideo
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ButtonVideoState();
}

class _ButtonVideoState extends State<ButtonVideo> {

  void _toggleVideo() {
    if (CallManager.shared.syncCall == null) {
      return;
    }

    CallManager.shared.syncCall.enableVideo();
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
        CallManager.shared.syncCall.videoEnabled ? 'images/ic_video.png' : 'images/ic_video_off.png',
        height: 75.0,
        width: 75.0,
      ),
    );
  }
}
