import 'package:call_sample/stringee_wrapper/call/stringee_call_manager.dart';
import 'package:call_sample/stringee_wrapper/common/result.dart';
import 'package:callkeep/callkeep.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../call/stringee_call_model.dart';
import '../interfaces/interfaces.dart';

class CallkeepManager implements CallkeepManagerInterface {
  static final CallkeepManager _instance = CallkeepManager._internal();

  factory CallkeepManager() {
    return _instance;
  }

  CallkeepManager._internal();

  final FlutterCallkeep callkeep = FlutterCallkeep();

  bool isActiveAudio = false;

  String _pushToken = '';
  String get pushToken => _pushToken;

  @override
  Future<Result> reportOutgoingCallIfNeeded({
    required StringeeCallModel stringeeCallModel,
  }) async {
    final uuid = const Uuid().v4();
    stringeeCallModel.setUuid(uuid);
    await callkeep.startCall(
      uuid,
      stringeeCallModel.to ?? '',
      stringeeCallModel.to ?? '',
      handleType: 'generic',
      hasVideo: stringeeCallModel.call.isVideoCall,
    );
    debugPrint(
        'reportOutgoingCallIfNeeded uuid: $uuid ${stringeeCallModel.call.to} ${stringeeCallModel.call.toAlias}');
    return Result.success('Report outgoing call callkit successfully');
  }

  @override
  Future<Result> reportIncomingCallIfNeeded(
      {required StringeeCallModel stringeeCallModel,
      bool fromPushKit = false}) async {
    CallInfo callInfo = await callkeep.getCallInfo(
        stringeeCallModel.call.callId ?? '',
        stringeeCallModel.call.serial ?? 1);
    debugPrint('reportIncomingCallIfNeeded call info ${callInfo.state}');
    if (callInfo.uuid != null && callInfo.uuid!.isNotEmpty) {
      if (callInfo.state == null) {
        await callkeep.displayIncomingCall(
          callInfo.uuid ?? '',
          'Stringeee',
          hasVideo: stringeeCallModel.call.isVideoCall,
          localizedCallerName:
              stringeeCallModel.call.fromAlias ?? 'Stringee User',
          handleType: 'generic',
        );
      } else if (callInfo.state == CallState.answered) {
        // TODO: - Answer call
        debugPrint('reportIncomingCallIfNeeded call answered');
      } else if (callInfo.state == CallState.ended) {
        // TODO: - End call
        debugPrint('reportIncomingCallIfNeeded call ended');
      }
    }
    return Result.success('Report incoming call callkit successfully');
  }

  @override
  Future<Result> answerCallIfNeeded(
      {required StringeeCallModel stringeeCallModel}) async {
    if (stringeeCallModel.isIncomingCall) {
      await callkeep.answerIncomingCall(stringeeCallModel.uuid);
    } else {
      await callkeep
          .reportConnectedOutgoingCallWithUUID(stringeeCallModel.uuid);
    }
    debugPrint(
        'answerCallIfNeeded uuid: ${stringeeCallModel.uuid} ${stringeeCallModel.call.to} ${stringeeCallModel.call.toAlias}');
    return Result.success('Answer callkit successfully');
  }

  @override
  Future<Result> endCallIfNeeded(
      {required StringeeCallModel stringeeCallModel}) async {
    if (await callkeep.isCallActive(stringeeCallModel.uuid)) {
      await callkeep.endCall(stringeeCallModel.uuid);

      // await callkeep.reportEndCallWithUUID(stringeeCallModel.uuid, 1);
      // if (stringeeCallModel.isIncomingCall) {
      //   await callkeep.endCall(stringeeCallModel.uuid);
      // }
    }
    return Result.success(
        'End callkit successfully ${stringeeCallModel.call.to} ${stringeeCallModel.call.toAlias}');
  }

  void configureCallKeep({String? appName}) {
    callkeep.setup(<String, dynamic>{
      'ios': {
        'appName': appName ?? 'Stringee',
      },
      'android': {
        'alertTitle': 'Permissions required',
        'alertDescription':
            'This application needs to access your phone accounts',
        'cancelButton': 'Cancel',
        'okButton': 'ok',
      },
    });

    _listenCallkitEvent();
  }

  _listenCallkitEvent() {
    // audio session
    callkeep.on(CallKeepDidActivateAudioSession(), (event) {
      isActiveAudio = true;
    });
    callkeep.on(CallKeepDidDeactivateAudioSession(), (event) {
      isActiveAudio = false;
    });

    // call actions
    callkeep.on(CallKeepDidReceiveStartCallAction(), (event) {
      // start a call
      debugPrint('CallKeepDidReceiveStartCallAction ${event.callUUID}');
      if (event.callUUID != null) {
        final call = StringeeCallManager().callWithUuid(event.callUUID!);
        if (call != null) {
          call.makeCall();
        }
      }
    });
    callkeep.on(CallKeepPerformAnswerCallAction(), (event) {
      // answer a call
      // TODO: - notify to your call P-C-M the answer action
      debugPrint('CallKeepPerformAnswerCallAction');
    });
    callkeep.on(CallKeepPerformEndCallAction(), (event) {
      if (event.callUUID != null) {
        final call = StringeeCallManager().callWithUuid(event.callUUID!);
        if (call != null) {
          StringeeCallManager().endStringeeCall(call);
        }
      }
    });

    callkeep.on(CallKeepDidDisplayIncomingCall(), (event) {
      debugPrint('CallKeepDidDisplayIncomingCall ${event.callUUID}');

      // TODO: - notify to your call P-C-M the incoming call
      // Timer(Duration(seconds: 3), () {
      //   debugPrint('check active call after 3s');
      //   (String, int)? currentCall = CallWrapper().currentCallIdAndSerial();
      //   callkeep
      //       .getCallInfo(currentCall?.$1 ?? '', currentCall?.$2 ?? 1)
      //       .then((value) => {
      //             if (event.callUUID != value.uuid)
      //               {callkeep.endCall(event.uuid ?? '')}
      //           });
      // });
    });

    callkeep.on(CallKeepDidPerformSetMutedCallAction(), (event) {
      // mute/unmute call
      debugPrint(
          'CallKeepDidPerformSetMutedCallAction ${event.callUUID} ${event.muted}');
    });

    callkeep.on(CallKeepDidToggleHoldAction(), (event) {
      // hold/unhold call
      debugPrint('CallKeepDidToggleHoldAction ${event.callUUID} ${event.hold}');
    });

    callkeep.on(CallKeepDidPerformDTMFAction(), (event) {
      // send DTMF tones
      debugPrint(
          'CallKeepDidPerformDTMFAction ${event.callUUID} ${event.digits}');
    });

    callkeep.on(CallKeepPushKitReceivedNotification(), (event) {
      // received pushkit notification
      debugPrint(
          'CallKeepPushKitReceivedNotification ${event.callId} ${event.uuid} ${event.serial} ${event.callId} ');
    });

    callkeep.on(CallKeepPushKitToken(), (event) {
      _pushToken = event.token ?? '';
      debugPrint('event token: ${event.token}');
    });
  }
}
