import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import 'listener/call_listener.dart';
import 'managers/call_manager.dart';
import 'managers/client_manager.dart';

class Call extends StatefulWidget {
  late String? _to;
  late bool _isVideoCall = false;
  late bool _isIncomingCall = false;
  late String? _callee;
  late CallManager? _callManager;

  static String routeName = 'Call';

  Call({
    super.key,
    String? to,
    bool? isVideoCall,
    bool? isIncomingCall,
    bool? isStringeeCall,
  }) {
    _isIncomingCall = isIncomingCall ?? false;
    _to = to;
    isVideoCall ??= false;
    if (!_isIncomingCall) {
      ClientManager().callManager = CallManager();
    }
    _callManager = ClientManager().callManager;

    _isVideoCall = _isIncomingCall ? _callManager!.isVideoCall : isVideoCall;

    if (!_isIncomingCall) {
      if (_callManager!.isCallNotInitialized()) {
        _callManager!.initializedOutgoingCall(
            _to!, _isVideoCall, isStringeeCall ?? false);
      }
      _callee = _to;
    } else {
      if (isStringeeCall ?? false) {
        _callee = _callManager!.getFrom();
      } else {
        _callee = _callManager!.getFrom();
      }
    }
  }

  @override
  State<StatefulWidget> createState() {
    return _CallState();
  }
}

class _CallState extends State<Call> {
  late String _status;
  late String _time = '00:00';
  late bool _isMicOn;
  late bool _isVideoEnable;
  late bool _isSpeaker;
  bool _receivedLocalStream = false;
  bool _receivedRemoteStream = false;
  Timer? _timer;

  @override
  void dispose() {
    super.dispose();
    if (_timer != null) {
      _timer!.cancel();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.bottom]);
    _status = widget._callManager!.callStatus.name;
    _isMicOn = widget._callManager!.isMicOn;
    _isVideoEnable = widget._callManager!.isVideoEnable;
    _isSpeaker = widget._callManager!.isSpeakerOn;

    widget._callManager!.registerEvent(CallListener(
      onCallStatus: (status) {
        setState(() {
          _status = status.name;
        });
        if (status == CallStatus.started) {
          startCallTimer();
        }
        if (status == CallStatus.busy || status == CallStatus.ended) {
          dismissCallingView();
        }
      },
      onError: (message) {
        dismissCallingView();
      },
      onReceiveLocalStream: () {
        setState(() {
          _receivedLocalStream = true;
        });
      },
      onReceiveRemoteStream: () {
        if (_receivedRemoteStream) {
          setState(() {
            _receivedRemoteStream = false;
          });
          setState(() {
            _receivedRemoteStream = true;
          });
        } else {
          setState(() {
            _receivedRemoteStream = true;
          });
        }
      },
      onSpeakerChange: (isOn) {
        setState(() {
          _isSpeaker = isOn;
        });
      },
      onMicChange: (isOn) {
        setState(() {
          _isMicOn = isOn;
        });
      },
      onVideoChange: (isOn) {
        setState(() {
          _isVideoEnable = isOn;
        });
      },
    ));
    if (!widget._isIncomingCall) {
      widget._callManager!.makeCall();
    }
  }

  void switchPress() {
    widget._callManager!.switchCamera();
  }

  void mutePress() {
    widget._callManager!.mute();
  }

  void speakerPress() {
    widget._callManager!.changeSpeaker();
  }

  void videoPress() {
    widget._callManager!.enableVideo();
  }

  void answerCall() {
    widget._callManager!.answer();
  }

  void endPress() {
    widget._callManager!.endCall(true);
  }

  void rejectPress() {
    widget._callManager!.endCall(false);
  }

  void dismissCallingView() {
    widget._callManager!.release();
    Navigator.pop(context);
  }

  void startCallTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      int second = timer.tick.toDouble().remainder(60).toInt();
      int minute = timer.tick.toDouble() ~/ 60;
      setState(() {
        _time =
            '${minute < 10 ? '0$minute' : minute}:${second < 10 ? '0$second' : second}';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget btnAnswer = GestureDetector(
      onTap: answerCall,
      child: Image.asset(
        'images/icn_answer/ic-answer-new.png',
        height: 70.0,
        width: 70.0,
      ),
    );

    Widget btnEnd = GestureDetector(
      onTap: endPress,
      child: Image.asset(
        'images/icn_end_call/ic-end-call-new.png',
        height: 70.0,
        width: 70.0,
      ),
    );

    Widget btnReject = GestureDetector(
      onTap: rejectPress,
      child: Image.asset(
        'images/icn_end_call/ic-end-call-new.png',
        height: 70.0,
        width: 70.0,
      ),
    );

    Widget btnSpeaker = GestureDetector(
      onTap: speakerPress,
      child: Image.asset(
        _isSpeaker
            ? 'images/icn_off_speaker/ic-speaker-selected-new.png'
            : 'images/icn_speaker/ic-speaker-new.png',
        height: 70.0,
        width: 70.0,
      ),
    );

    Widget btnMic = GestureDetector(
      onTap: mutePress,
      child: Image.asset(
        _isMicOn
            ? 'images/icn_mute/ic-mute-new.png'
            : 'images/icn_un_mute/ic-mute-selected-new.png',
        height: 70.0,
        width: 70.0,
      ),
    );

    Widget btnVideo = GestureDetector(
      onTap: videoPress,
      child: Image.asset(
        _isVideoEnable
            ? 'images/icn_open_video/ic-video-new.png'
            : 'images/icn_turn_off_video/ic-video-selected-new.png',
        height: 70.0,
        width: 70.0,
      ),
    );

    Widget btnSwitch = GestureDetector(
      onTap: switchPress,
      child: Image.asset(
        'images/icn_switch_camera/ic-switch-camera-new.png',
        height: 70.0,
        width: 70.0,
      ),
    );

    Widget localView = (_receivedLocalStream &&
            widget._isVideoCall &&
            widget._callManager!.getCallId().isNotEmpty)
        ? StringeeVideoView(
            widget._callManager!.getCallId(),
            true,
            alignment: Alignment.topLeft,
            margin: const EdgeInsets.only(top: 80.0, left: 20.0),
            height: 150.0,
            width: 110.0,
            scalingType: ScalingType.fit,
          )
        : Placeholder(
            color: Colors.transparent,
            child: Container(
              alignment: Alignment.topLeft,
              margin: const EdgeInsets.only(top: 80.0, left: 20.0),
              height: 150.0,
              width: 110.0,
            ),
          );

    Widget remoteView = (_receivedRemoteStream &&
            widget._isVideoCall &&
            widget._callManager!.getCallId().isNotEmpty)
        ? StringeeVideoView(
            widget._callManager!.getCallId(),
            false,
            isMirror: false,
            scalingType: ScalingType.fit,
          )
        : Placeholder(
            color: Colors.transparent,
            child: Container(
              color: Colors.black,
            ),
          );

    Widget avatar = Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 50.0),
      child: CircleAvatar(
        radius: 60,
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: 57,
          backgroundColor: const Color.fromRGBO(64, 182, 73, 1.0),
          child: Text(
            widget._callee!.characters.first.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 50.0,
            ),
          ),
        ),
      ),
    );

    Widget timer = Container(
      height: 30.0,
      width: 55.0,
      decoration: const BoxDecoration(
        color: Color.fromRGBO(64, 182, 73, 1.0),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(5.0),
          bottomLeft: Radius.circular(5.0),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(left: 8.0),
        alignment: Alignment.centerLeft,
        child: Text(
          _time.isEmpty || _status != CallStatus.started.name ? "" : _time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.0,
          ),
        ),
      ),
    );

    Widget status = Text(
      _status,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 15.0,
      ),
    );

    Widget dividerStatus = Container(
      margin: const EdgeInsets.only(top: 5.0),
      height: 2.0,
      width: 20.0,
      decoration: const BoxDecoration(
        color: Color.fromRGBO(64, 182, 73, 1.0),
      ),
    );

    Widget callee = Container(
      margin: const EdgeInsets.only(top: 15.0),
      child: Text(
        widget._callee!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22.0,
        ),
      ),
    );

    Widget incomingCallWidget = Container(
      color: Colors.white,
      child: Stack(
        children: [
          FractionallySizedBox(
            heightFactor: 0.75,
            widthFactor: 1.0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 40.0),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(20.0),
                  bottomLeft: Radius.circular(20.0),
                ),
                color: Color.fromRGBO(26, 87, 141, 1.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  status,
                  dividerStatus,
                  callee,
                  const Divider(color: Colors.transparent, height: 30.0),
                  avatar,
                ],
              ),
            ),
          ),
          Container(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.25,
              widthFactor: 1.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  btnReject,
                  btnAnswer,
                ],
              ),
            ),
          ),
        ],
      ),
    );

    Widget inVoiceCallWidget = Container(
      color: Colors.white,
      child: Stack(
        children: [
          FractionallySizedBox(
            heightFactor: 0.75,
            widthFactor: 1.0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 40.0, top: 45.0),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(20.0),
                  bottomLeft: Radius.circular(20.0),
                ),
                color: Color.fromRGBO(26, 87, 141, 1.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              status,
                              dividerStatus,
                              callee,
                            ],
                          ),
                        ),
                        _status == CallStatus.started.name
                            ? timer
                            : const Placeholder(
                                color: Colors.transparent,
                                child: SizedBox(
                                  height: 30.0,
                                  width: 55.0,
                                ),
                              ),
                      ],
                    ),
                  ),
                  avatar,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      btnSpeaker,
                      btnMic,
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.25,
              widthFactor: 1.0,
              child: Center(
                child: btnEnd,
              ),
            ),
          ),
        ],
      ),
    );

    Widget inVideoCallWidget = Container(
      color: Color.fromRGBO(26, 87, 141, 1.0),
      child: Stack(
        children: [
          remoteView,
          localView,
          Container(
            margin: const EdgeInsets.only(top: 90.0),
            alignment: Alignment.topRight,
            child: _status == CallStatus.started.name
                ? timer
                : const Placeholder(
                    color: Colors.transparent,
                    child: SizedBox(
                      height: 30.0,
                      width: 55.0,
                    ),
                  ),
          ),
          Container(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.25,
              widthFactor: 1.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  btnVideo,
                  btnMic,
                  btnSwitch,
                  btnEnd,
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: _status == CallStatus.incoming.name
          ? incomingCallWidget
          : widget._isVideoCall
              ? inVideoCallWidget
              : inVoiceCallWidget,
    );
  }
}
