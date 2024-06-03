import 'package:call_sample/stringee_wrapper/widgets/sc_calling_widget.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../call/stringee_call_model.dart';
import 'call_action_widget.dart';
import 'stringee_call_widget.dart';

class StringeeIncallWidget extends StatelessWidget {
  const StringeeIncallWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<StringeeCallModel>();
    return model.isVideoCall
        ? _buildVideoCall(context, model)
        : _buildVoiceCall(context, model);
  }

  Widget _buildVoiceCall(BuildContext context, StringeeCallModel model) {
    return SCCallingWidget(
        body: Container(
          padding: const EdgeInsets.only(bottom: 40.0, top: 64),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            model.callState.name,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15.0,
                            ),
                          ),
                          dividerStatus,
                          Container(
                            margin: const EdgeInsets.only(top: 15.0),
                            child: Text(
                              model.callee ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
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
                    ),
                  ],
                ),
              ),
              StringeeAvatarWidget(text: model.callee),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _btnSpeaker(model),
                  _btnMic(model),
                ],
              ),
            ],
          ),
        ),
        bottom: Center(
          child: _btnEnd(model),
        ));
  }

  Widget _buildVideoCall(BuildContext context, StringeeCallModel model) {
    return Stack(
      children: [
        _remoteView(context, model),
        Positioned(
          right: 16,
          top: 64,
          child: _localView(context, model),
        ),

        // Call actions
        Positioned(
          bottom: 64,
          left: 24,
          right: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _btnVideo(model),
              _btnMic(model),
              _btnSwitch(model),
              _btnEnd(model),
            ],
          ),
        ),
      ],
    );
  }

  Widget _localView(BuildContext context, StringeeCallModel model) {
    return model.readyLocalView
        ? StringeeVideoView(
            model.call.callId,
            true,
            height: 150.0,
            width: 110.0,
            scalingType: ScalingType.fit,
            borderRadius: BorderRadius.circular(8),
          )
        : const Placeholder(
            color: Colors.black,
          );
  }

  Widget _remoteView(BuildContext context, StringeeCallModel model) {
    return model.readyRemoteView
        ? StringeeVideoView(
            model.call.callId,
            false,
            isMirror: false,
            scalingType: ScalingType.fit,
          )
        : const Placeholder(color: Colors.black );
  }

  Widget _btnMic(StringeeCallModel model) {
    return CallActionWidget(
      iconPath: !model.isMute
          ? 'assets/icons/ic-mute-new.png'
          : 'assets/icons/ic-mute-selected-new.png',
      onPressed: () {
        model.muteCall();
      },
    );
  }

  Widget _btnVideo(StringeeCallModel model) {
    return CallActionWidget(
      iconPath: model.isVideoEnable
          ? 'assets/icons/ic-video-new.png'
          : 'assets/icons/ic-video-selected-new.png',
      onPressed: () {
        model.enableVideo();
      },
    );
  }

  Widget _btnSpeaker(StringeeCallModel model) {
    return CallActionWidget(
      iconPath: model.isSpeaker
          ? 'assets/icons/ic-speaker-selected-new.png'
          : 'assets/icons/ic-speaker-new.png',
      onPressed: () {
        model.changeSpeaker();
      },
    );
  }

  Widget _btnEnd(StringeeCallModel model) {
    return CallActionWidget(
      iconPath: 'assets/icons/ic-end-call-new.png',
      onPressed: () {
        model.hangupCall();
      },
    );
  }

  Widget _btnSwitch(StringeeCallModel model) {
    return CallActionWidget(
      iconPath: 'assets/icons/ic-switch-camera-new.png',
      onPressed: () {
        model.switchCamera();
      },
    );
  }
}
