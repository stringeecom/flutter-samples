import 'package:call_sample/stringee_wrapper/call/stringee_call_model.dart';
import 'package:call_sample/stringee_wrapper/common/common.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_action_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../stringee_wrapper.dart';

class StringeeCallWidget extends StatefulWidget {
  const StringeeCallWidget({super.key});

  @override
  State<StringeeCallWidget> createState() => _StringeeCallWidgetState();
}

class _StringeeCallWidgetState extends State<StringeeCallWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // TODO: - handle specify platform
    if (isIOS) {
      //
    } else {
      // android
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO: - do something if
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  Widget btnAnswer() {
    return CallActionWidget(
      iconPath: 'assets/icons/ic-answer-new.png',
      onPressed: () {
        Provider.of<StringeeCallModel>(context, listen: false).answerCall();
      },
    );
  }

  Widget btnEnd() {
    return CallActionWidget(
      iconPath: 'assets/icons/ic-end-call-new.png',
      onPressed: () {
        Provider.of<StringeeCallModel>(context, listen: false).hangupCall();
      },
    );
  }

  Widget btnReject() {
    return CallActionWidget(
      iconPath: 'assets/icons/ic-end-call-new.png',
      onPressed: () {
        Provider.of<StringeeCallModel>(context, listen: false).rejectCall();
      },
    );
  }

  Widget btnSwitch() {
    return CallActionWidget(
        iconPath: 'assets/icons/ic-switch-camera-new.png',
        onPressed: () {
          Provider.of<StringeeCallModel>(context, listen: false).switchCamera();
        });
  }

  Widget btnSpeaker() {
    return CallActionWidget(
      iconPath: Provider.of<StringeeCallModel>(context).isSpeaker
          ? 'assets/icons/ic-speaker-selected-new.png'
          : 'assets/icons/ic-speaker-new.png',
      onPressed: () {
        Provider.of<StringeeCallModel>(context, listen: false).changeSpeaker();
      },
    );
  }

  Widget btnMic() {
    return CallActionWidget(
      iconPath: Provider.of<StringeeCallModel>(context).isMicOn
          ? 'assets/icons/ic-mute-new.png'
          : 'assets/icons/ic-mute-selected-new.png',
      onPressed: () {
        Provider.of<StringeeCallModel>(context, listen: false).muteCall();
      },
    );
  }

  Widget btnVideo() {
    return CallActionWidget(
      iconPath: Provider.of<StringeeCallModel>(context).isVideoEnable
          ? 'assets/icons/ic-video-new.png'
          : 'assets/icons/ic-video-selected-new.png',
      onPressed: () {
        Provider.of<StringeeCallModel>(context, listen: false).enableVideo();
      },
    );
  }

  Widget _localView() {
    final model = Provider.of<StringeeCallModel>(context);
    return model.readyLocalView
        ? StringeeVideoView(
            model.call.callId,
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
  }

  Widget _remoteView() {
    final model = Provider.of<StringeeCallModel>(context);
    return model.readyRemoteView
        ? StringeeVideoView(
            model.call.callId,
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
  }

  Widget _avatar() {
    final model = Provider.of<StringeeCallModel>(context);
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 50.0),
      child: CircleAvatar(
        radius: 60,
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: 57,
          backgroundColor: const Color.fromRGBO(64, 182, 73, 1.0),
          child: Text(
            model.callee != null && model.callee!.isNotEmpty
                ? model.callee!.characters.first.toUpperCase()
                : '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 50.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _timerCall() {
    final model = Provider.of<StringeeCallModel>(context, listen: true);
    return Container(
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
          model.time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<StringeeCallModel>(context, listen: true);
    Widget status = Text(
      model.signalingState.name,
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
        model.callee ?? '',
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
                  _avatar(),
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
                  btnReject(),
                  btnAnswer(),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              status,
                              dividerStatus,
                              callee,
                            ],
                          ),
                        ),
                        model.signalingState == StringeeSignalingState.answered
                            ? _timerCall()
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
                  _avatar(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      btnSpeaker(),
                      btnMic(),
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
                child: btnEnd(),
              ),
            ),
          ),
        ],
      ),
    );

    Widget inVideoCallWidget = Container(
      color: Colors.black,
      child: Stack(
        children: [
          _remoteView(),
          _localView(),
          Container(
            margin: const EdgeInsets.only(top: 90.0),
            alignment: Alignment.topRight,
            child: model.signalingState == StringeeSignalingState.answered
                ? _timerCall()
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
                  btnVideo(),
                  btnMic(),
                  btnSwitch(),
                  btnEnd(),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: model.signalingState == StringeeSignalingState.ringing
          ? incomingCallWidget
          : model.isVideoCall
              ? inVideoCallWidget
              : inVoiceCallWidget,
    );
  }

  void dismissCallingView(String message) {
    debugPrint('dismissCallingView: $message');
    StringeeWrapper().stringeeListener?.onDismissCallWidget.call(message);
  }
}
