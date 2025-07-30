import 'package:call_sample/stringee_wrapper/call/stringee_call_model.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_button_audio.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_button_end.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_button_mic.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_button_switch.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_button_video.dart';
import 'package:call_sample/stringee_wrapper/widgets/sc_calling_widget.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

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
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _btnAudio(context, model),
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
        Positioned(
          top: 64,
          left: 16,
          child: Container(
            height: 30.0,
            width: 55.0,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(64, 182, 73, 1.0),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: Text(
              model.time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.0,
              ),
            ),
          ),
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
    if (model.localVideoTrack != null) {
      return model.localVideoTrack!.attach(
        isMirror: true,
        height: 150.0,
        width: 110.0,
        scalingType: ScalingType.fit,
        // borderRadius: BorderRadius.circular(8),
      );
    }
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
    if (model.remoteVideoTrack != null) {
      return model.remoteVideoTrack!.attach(
        isMirror: false,
        scalingType: ScalingType.fit,
      );
    }
    return model.readyRemoteView
        ? StringeeVideoView(
            model.call.callId,
            false,
            isMirror: false,
            scalingType: ScalingType.fit,
          )
        : const Placeholder(color: Colors.black);
  }

  Widget _btnMic(StringeeCallModel model) {
    return CallButtonMic(
      enabled: !model.isMute,
      onPressed: () {
        model.muteCall();
      },
    );
  }

  Widget _btnVideo(StringeeCallModel model) {
    return CallButtonVideo(
      enabled: model.isVideoEnable,
      onPressed: () {
        model.enableVideo();
      },
    );
  }

  Widget _btnAudio(BuildContext context, StringeeCallModel model) {
    return CallButtonAudio(
      audioDevice: model.audioDevice,
      onPressed: () {
        if (model.availableAudioDevices.length < 3) {
          if (model.availableAudioDevices.length <= 1) {
            return;
          }
          int position = model.availableAudioDevices.indexOf(model.audioDevice);
          if (position == model.availableAudioDevices.length - 1) {
            model.changeAudioDevice(model.availableAudioDevices[0]);
          } else {
            model.changeAudioDevice(model.availableAudioDevices[position + 1]);
          }
        } else {
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return ListView.separated(
                itemCount: model.availableAudioDevices.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) => ListTile(
                  title: Text(model.availableAudioDevices[index].name!),
                  onTap: () {
                    model.changeAudioDevice(model.availableAudioDevices[index]);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          );
        }
      },
    );
  }

  Widget _btnEnd(StringeeCallModel model) {
    return CallButtonEnd(
      onPressed: () {
        model.hangupCall();
      },
    );
  }

  Widget _btnSwitch(StringeeCallModel model) {
    return CallButtonSwitch(
      onPressed: () {
        model.switchCamera();
      },
    );
  }
}
