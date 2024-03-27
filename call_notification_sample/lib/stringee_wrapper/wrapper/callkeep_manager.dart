import 'dart:async';

import 'package:callkeep/callkeep.dart';
import 'package:flutter/cupertino.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import 'stringee_wrapper.dart';

class CallkeepManager {
  static CallkeepManager? _instance;
  String? pushToken;
  final FlutterCallkeep callkeep = FlutterCallkeep();
  late bool isActiveAudio = false;
  bool isPushRegistered = false;

  static CallkeepManager? get shared {
    if (_instance == null) {
      _instance = CallkeepManager._privateConstructor();
    }
    return _instance;
  }

  CallkeepManager._privateConstructor();

  Future<void> reportIncomingCallIfNeeded(
      bool isCall1, StringeeCall? call1, StringeeCall2? call2) async {
    if (isCall1) {
      CallInfo callInfo =
          await callkeep.getCallInfo(call1?.id ?? '', call1?.serial ?? 1);
      debugPrint('call info ${callInfo.state}');
      if (callInfo.uuid != null && callInfo.uuid!.isNotEmpty) {
        if (callInfo.state == null) {
          await callkeep.displayIncomingCall(callInfo.uuid ?? '', 'Stringee',
              hasVideo: call1?.isVideoCall ?? false,
              localizedCallerName: call1?.fromAlias ?? 'Stringee User');
        } else if (callInfo.state == CallState.answered) {
          CallWrapper().answer();
        } else if (callInfo.state == CallState.ended) {
          CallWrapper().endCall(false);
        }
      }
    } else {
      CallInfo callInfo =
          await callkeep.getCallInfo(call2?.id ?? '', call2?.serial ?? 1);
      if (callInfo.uuid != null && callInfo.uuid!.isNotEmpty) {
        if (callInfo.state == null) {
          await callkeep.displayIncomingCall(callInfo.uuid ?? '', 'Stringee',
              hasVideo: call2?.isVideoCall ?? false,
              localizedCallerName: call2?.fromAlias ?? 'Stringee User');
        } else if (callInfo.state == CallState.answered) {
          CallWrapper().answer();
        } else if (callInfo.state == CallState.ended) {
          CallWrapper().endCall(false);
        }
      }
    }
  }

  Future<void> answerCallKeepIfNeed(
      bool isCall1, StringeeCall? call1, StringeeCall2? call2) async {
    CallInfo? callInfo;
    if (isCall1) {
      callInfo =
          await callkeep.getCallInfo(call1?.id ?? '', call1?.serial ?? 1);
    } else {
      callInfo =
          await callkeep.getCallInfo(call2?.id ?? '', call2?.serial ?? 1);
    }
    if (callInfo.uuid != null && callInfo.state == CallState.ringing) {
      await callkeep.answerIncomingCall(callInfo.uuid ?? '');
    }
  }

  Future<void> endCallKeepIfNeed(
      bool isCall1, StringeeCall? call1, StringeeCall2? call2) async {
    CallInfo? callInfo;
    if (isCall1) {
      callInfo =
          await callkeep.getCallInfo(call1?.id ?? '', call1?.serial ?? 1);
    } else {
      callInfo =
          await callkeep.getCallInfo(call2?.id ?? '', call2?.serial ?? 1);
    }
    if (callInfo.uuid != null && callInfo.state != CallState.ended) {
      await callkeep.endCall(callInfo.uuid ?? '');
    }
  }

  void configureCallKeep() {
    callkeep.setup(<String, dynamic>{
      'ios': {
        'appName': 'Stringee',
      },
      'android': {
        'alertTitle': 'Permissions required',
        'alertDescription':
            'This application needs to access your phone accounts',
        'cancelButton': 'Cancel',
        'okButton': 'ok',
      },
    });
    debugPrint('configureCallKeep');
    callkeep.on(CallKeepPushKitToken(), (event) {
      CallkeepManager.shared?.pushToken = event.token;
      debugPrint('event token: ${event.token}');
      if (!isPushRegistered) {
        isPushRegistered = true;
        StringeeWrapper()
            .registerPush(event.token ?? '', isVoip: true, isProduction: false);
      }
    });

    callkeep.on(CallKeepDidActivateAudioSession(), (event) {
      isActiveAudio = true;
    });
    callkeep.on(CallKeepDidDeactivateAudioSession(), (event) {
      isActiveAudio = false;
    });
    callkeep.on(CallKeepPerformAnswerCallAction(), (event) {
      (String, int)? currentCall = CallWrapper().currentCallIdAndSerial();
      callkeep
          .getCallInfo(currentCall?.$1 ?? '', currentCall?.$2 ?? 1)
          .then((value) => {
                if (event.callUUID == value.uuid) {CallWrapper().answer()}
              });
    });
    callkeep.on(CallKeepPerformEndCallAction(), (event) {
      (String, int)? currentCall = CallWrapper().currentCallIdAndSerial();
      callkeep
          .getCallInfo(currentCall?.$1 ?? '', currentCall?.$2 ?? 1)
          .then((value) => {
                if (event.callUUID == value.uuid)
                  {CallWrapper().endCall(value.state == CallState.answered)}
              });
    });
    callkeep.on(CallKeepDidDisplayIncomingCall(), (event) {
      Timer(Duration(seconds: 3), () {
        debugPrint('check active call after 3s');
        (String, int)? currentCall = CallWrapper().currentCallIdAndSerial();
        callkeep
            .getCallInfo(currentCall?.$1 ?? '', currentCall?.$2 ?? 1)
            .then((value) => {
                  if (event.callUUID != value.uuid)
                    {callkeep.endCall(event.uuid ?? '')}
                });
      });
    });
  }
}
