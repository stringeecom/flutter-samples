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

  // current call uuid handled by callkit
  // TODO: - change with more properties if needed to handle multiple calls or complex call flow
  String _currentCallUuid = '';

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
    _currentCallUuid = uuid;
    debugPrint(
        'reportOutgoingCallIfNeeded uuid: $uuid ${stringeeCallModel.call.to} ${stringeeCallModel.call.toAlias}');
    return Result.success('Report outgoing call callkit successfully');
  }

  @override
  Future<Result> reportIncomingCallIfNeeded(
      {required StringeeCallModel stringeeCallModel,
      bool fromPushKit = false}) async {
    debugPrint(
        'reportIncomingCallIfNeeded current: $_currentCallUuid uuid: ${stringeeCallModel.uuid}, from: ${stringeeCallModel.call.callId} ${stringeeCallModel.call.from}');
    if (_currentCallUuid.isEmpty) {
      final uuid = const Uuid().v4();
      stringeeCallModel.setUuid(uuid);
      _currentCallUuid = uuid;
      await callkeep.displayIncomingCall(
        uuid,
        stringeeCallModel.call.from ?? '',
        handleType: 'generic',
        hasVideo: stringeeCallModel.call.isVideoCall,
      );
    } else {
      // call already handled from pushkit
      // set current uuid to call model
      stringeeCallModel.setUuid(_currentCallUuid);
    }
    return Result.success('Report incoming call callkit successfully');
  }

  @override
  Future<Result> answerCallIfNeeded(
      {required StringeeCallModel stringeeCallModel}) async {
    if (stringeeCallModel.uuid.isEmpty) {
      return Result.failure('uuid is empty');
    }
    debugPrint(
        ' answerCallIfNeeded ${stringeeCallModel.uuid} isIncoming ${stringeeCallModel.isIncomingCall}');
    if (stringeeCallModel.isIncomingCall) {
      await callkeep.answerIncomingCall(stringeeCallModel.uuid);
    } else {
      await callkeep
          .reportConnectedOutgoingCallWithUUID(stringeeCallModel.uuid);
    }
    return Result.success('Answer callkit successfully');
  }

  @override
  Future<Result> reportEndCallIfNeeded(
      {required StringeeCallModel stringeeCallModel, int? reason}) async {
    if (stringeeCallModel.uuid.isEmpty) {
      return Result.failure('uuid is empty');
    }
    debugPrint(
        'reportEndCallIfNeeded currentCallUuid:$_currentCallUuid ${stringeeCallModel.uuid} reason $reason');
    if (reason == null) {
      await callkeep.endCall(stringeeCallModel.uuid);
    } else {
      await callkeep.reportEndCallWithUUID(stringeeCallModel.uuid, reason);
      // after report, end stringee call
      _endCall(stringeeCallModel.uuid);
    }
    _currentCallUuid = '';
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
      debugPrint('CallKeepDidActivateAudioSession');
      isActiveAudio = true;
    });
    callkeep.on(CallKeepDidDeactivateAudioSession(), (event) {
      debugPrint('CallKeepDidDeactivateAudioSession');
      isActiveAudio = false;
    });

    // call actions
    callkeep.on(CallKeepDidReceiveStartCallAction(), (event) {
      // start a call
      // debugPrint('CallKeepDidReceiveStartCallAction ${event.callUUID}');
      // if (event.callUUID != null) {
      //   final call = StringeeCallManager().callWithUuid(event.callUUID!);
      //   if (call != null) {
      //     call.makeCall();
      //   }
      // }
    });
    callkeep.on(CallKeepPerformAnswerCallAction(), (event) {
      // answer a call
      debugPrint('CallKeepPerformAnswerCallAction ${event.callUUID}');
      if (event.callUUID != null) {
        _answerCall(event.callUUID!);
      }
    });
    callkeep.on(CallKeepPerformEndCallAction(), (event) {
      if (event.callUUID != null) {
        _endCall(event.callUUID!);
      }
    });

    callkeep.on(CallKeepDidDisplayIncomingCall(), (event) {
      debugPrint(
          'CallKeepDidDisplayIncomingCall ${event.callUUID} ${event.callId}');

      // final hasVideo = event.hasVideo ?? false;

      // if call was handled in app
      if (_currentCallUuid.isNotEmpty) {
        // report call already handled
        // end call from pushkit
        if (event.uuid != null &&
            event.uuid!.isNotEmpty &&
            event.fromPushKit == true) {
          final call = StringeeCallManager().callWithUuid(_currentCallUuid);
          if (call != null && call.call.callId == event.callId) {
            debugPrint(
                'CallKeepPushKitReceivedNotification currentUuid: $_currentCallUuid end call ${event.uuid}');
            callkeep.endCall(event.uuid!);
          }
        }
      } else {
        // set current call uuid from pushkit
        if (event.uuid != null && event.uuid!.isNotEmpty) {
          _currentCallUuid = event.uuid!;
        }
      }
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

    callkeep.on(CallKeepPushKitReceivedNotification(), (event) {});

    callkeep.on(CallKeepPushKitToken(), (event) {
      _pushToken = event.token ?? '';
    });
  }

  // end stringee call
  _endCall(String uuid) {
    final call = StringeeCallManager().callWithUuid(uuid);
    if (call != null) {
      StringeeCallManager().endStringeeCall(call);
      _currentCallUuid = '';
    }
  }

  // answer stringee call
  _answerCall(String uuid) {
    final call = StringeeCallManager().callWithUuid(uuid);
    if (call != null) {
      call.startTimerIfNeeded();
      StringeeCallManager().answerStringeeCall(call);
    }
  }
}
