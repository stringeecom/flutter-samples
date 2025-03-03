import 'dart:async';

import 'package:call_sample/stringee_wrapper/call/stringee_call_manager.dart';
import 'package:callkeep/callkeep.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../call/stringee_call_model.dart';
import '../common/response.dart';
import 'call_kit_model.dart';

class CallkeepManager {
  static final CallkeepManager _instance = CallkeepManager._internal();

  factory CallkeepManager() {
    return _instance;
  }

  CallkeepManager._internal();

  final FlutterCallkeep callkeep = FlutterCallkeep();

  bool _isActiveAudio = false;

  bool get isActiveAudio => _isActiveAudio;

  // current call uuid handled by callkit
  // to handle multi call change to list if needed
  CallKitModel _currentCallKit = CallKitModel();

  /// list of handled call uuids (handled by callkit) but not found in stringee calls
  /// end/answer call in callkit but not have stringee call to handle
  final List<CallKitModel> _handledCallUuids = [];

  String _pushToken = '';

  String get pushToken => _pushToken;

  /// report outgoing call to callkit
  Future<Response> reportOutgoingCallIfNeeded(
      StringeeCallModel stringeeCallModel) async {
    final uuid = const Uuid().v4();
    stringeeCallModel.setUuid(uuid);
    await callkeep.startCall(
      uuid,
      stringeeCallModel.to ?? '',
      stringeeCallModel.to ?? '',
      handleType: 'generic',
      hasVideo: stringeeCallModel.call.isVideoCall,
    );
    _currentCallKit = CallKitModel(
      uuid: uuid,
      callId: stringeeCallModel.call.callId,
      serial: stringeeCallModel.call.serial,
      callModel: stringeeCallModel,
    );
    debugPrint(
        'reportOutgoingCallIfNeeded uuid: $uuid ${stringeeCallModel.call.to} ${stringeeCallModel.call.toAlias}');
    return Response.success('Report outgoing call callkit successfully');
  }

  /// report incoming call to callkit if needed
  Future<Response> reportIncomingCallIfNeeded(
      StringeeCallModel stringeeCallModel) async {
    debugPrint(
        'reportIncomingCallIfNeeded current:${_currentCallKit.uuid} uuid: ${stringeeCallModel.uuid}, from: ${stringeeCallModel.call.callId} ${stringeeCallModel.call.from} hasVideo: ${stringeeCallModel.call.isVideoCall}');
    if (_currentCallKit.uuid == null) {
      final uuid = const Uuid().v4();
      stringeeCallModel.setUuid(uuid);
      _currentCallKit = CallKitModel(
        uuid: uuid,
        callId: stringeeCallModel.call.callId,
        serial: stringeeCallModel.call.serial,
        callModel: stringeeCallModel,
      );
      await callkeep.displayIncomingCall(
        uuid,
        stringeeCallModel.call.from ?? '',
        localizedCallerName: stringeeCallModel.call.fromAlias ?? '',
        handleType: 'generic',
        hasVideo: stringeeCallModel.call.isVideoCall,
      );
    } else if (_currentCallKit.callId == stringeeCallModel.call.callId &&
        _currentCallKit.serial == stringeeCallModel.call.serial) {
      // check if the call is already handled
      // call already handled from pushkit
      // set current uuid to call model
      stringeeCallModel.setUuid(_currentCallKit.uuid!);
      _currentCallKit.callModel = stringeeCallModel;
      _currentCallKit.stopCountTimeout();

      // check if call have answer in callkit before if needed
      if (_handledCallUuids
          .where((element) => element.uuid == _currentCallKit.uuid)
          .isNotEmpty) {
        StringeeCallManager().answerStringeeCall(stringeeCallModel);
        _handledCallUuids
            .removeWhere((element) => element.uuid == _currentCallKit.uuid);
      }
    } else {
      // TODO: - incoming all different current call from pushkit
    }
    return Response.success('Report incoming call callkit successfully');
  }

  /// answer call from callkit if needed
  Future<Response> answerCallIfNeeded(
      StringeeCallModel stringeeCallModel) async {
    if (stringeeCallModel.uuid.isEmpty) {
      return Response.failure('uuid is empty');
    }
    debugPrint(
        ' answerCallIfNeeded ${stringeeCallModel.uuid} isIncoming ${stringeeCallModel.isIncomingCall}');
    if (stringeeCallModel.isIncomingCall) {
      await callkeep.answerIncomingCall(stringeeCallModel.uuid);
    } else {
      await callkeep
          .reportConnectedOutgoingCallWithUUID(stringeeCallModel.uuid);
    }
    return Response.success('Answer callkit successfully');
  }

  /// end call from callkit if needed
  Future<Response> reportEndCallIfNeeded(
      {required StringeeCallModel stringeeCallModel, int? reason}) async {
    if (stringeeCallModel.uuid.isEmpty) {
      return Response.failure('uuid is empty');
    }
    debugPrint(
        'reportEndCallIfNeeded currentCallUuid:${_currentCallKit.uuid} ${stringeeCallModel.uuid} reason $reason');
    if (_currentCallKit.uuid != stringeeCallModel.uuid) {
      return Response.failure('uuid is not matched');
    }
    if (reason == null) {
      await callkeep.endCall(stringeeCallModel.uuid);
    } else {
      await callkeep.reportEndCallWithUUID(stringeeCallModel.uuid, reason);
      // reason -1000: handleOnAnotherDevice, do not need end stringee call
      if (reason != -1000) {
        // after report, end stringee call
        _endCall(stringeeCallModel.uuid);
      }
    }
    _currentCallKit = CallKitModel();
    return Response.success(
        'End callkit successfully ${stringeeCallModel.call.to} ${stringeeCallModel.call.toAlias}');
  }

  /// mute call from callkit if needed
  Future<Response> reportMuteCallIfNeeded({
    required StringeeCallModel stringeeCallModel,
    required bool muted,
  }) async {
    if (stringeeCallModel.uuid.isEmpty) {
      return Response.failure('uuid is empty');
    }
    debugPrint('reportMuteCallIfNeeded ${stringeeCallModel.uuid} $muted');
    await callkeep.setMutedCall(stringeeCallModel.uuid, muted);
    return Response.success('Mute callkit successfully');
  }

  /// check if callkit has active call
  Future<bool> hasActiveCall() async {
    // current callkeep doesn't support get all active calls
    // so we need to check if there is any stringee call is active
    final calls = StringeeCallManager().calls;
    if (calls.isEmpty) {
      return false;
    }
    bool hasActiveCall = false;
    for (final call in calls) {
      final isActive = await callkeep.isCallActive(call.uuid);
      if (isActive) {
        hasActiveCall = true;
        break;
      }
    }
    return hasActiveCall;
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
      _isActiveAudio = true;
    });
    callkeep.on(CallKeepDidDeactivateAudioSession(), (event) {
      debugPrint('CallKeepDidDeactivateAudioSession');
      _isActiveAudio = false;
    });

    // call actions
    callkeep.on(CallKeepDidReceiveStartCallAction(), (event) {});
    callkeep.on(CallKeepPerformAnswerCallAction(), (event) {
      // answer a call
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
      if (_currentCallKit.uuid != null) {
        // report call already handled
        // end call from pushkit
        if (event.uuid != null &&
            event.uuid!.isNotEmpty &&
            event.fromPushKit == true) {
          final call =
              StringeeCallManager().callWithUuid(_currentCallKit.uuid!);
          if (call != null && call.call.callId == event.callId) {
            debugPrint(
                'CallKeepDidDisplayIncomingCall currentUuid: ${_currentCallKit.uuid} end call ${event.uuid}');
            callkeep.endCall(event.uuid!);
          }
        }
      } else {
        // set current call uuid from pushkit
        if (event.uuid != null && event.uuid!.isNotEmpty) {
          _currentCallKit = CallKitModel(
            uuid: event.uuid,
            callId: event.callId,
            serial: event.serial,
          );
        }
      }
    });

    callkeep.on(CallKeepDidPerformSetMutedCallAction(), (event) {
      // mute/unmute call
      if (event.callUUID != null && event.muted != null) {
        _muteCall(event.callUUID!, event.muted!);
      }
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

  _muteCall(String uuid, bool muted) {
    final call = StringeeCallManager().callWithUuid(uuid);
    if (call != null) {
      call.mute(muted);
    }
  }

  // end stringee call
  _endCall(String uuid) {
    final call = StringeeCallManager().callWithUuid(uuid);
    if (call != null) {
      StringeeCallManager().endStringeeCall(call);
      _currentCallKit = CallKitModel();
    }
  }

  // answer stringee call
  _answerCall(String uuid) {
    final call = StringeeCallManager().callWithUuid(uuid);
    if (call != null) {
      call.startTimerIfNeeded();
      StringeeCallManager().answerStringeeCall(call);
    } else {
      /// store uuid to handle later
      if (_currentCallKit.uuid != null) {
        _handledCallUuids.add(_currentCallKit);
      }
    }
  }

  removeCallKitModel(String uuid) {
    if (_currentCallKit.uuid == uuid) {
      _currentCallKit = CallKitModel();
    }
  }
}
